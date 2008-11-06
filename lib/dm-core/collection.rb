module DataMapper
  # The Collection class represents a list of resources persisted in
  # a repository and identified by a query.
  #
  # A Collection should act like an Array in every way, except that
  # it will attempt to defer loading until the results from the
  # repository are needed.
  #
  # A Collection is typically returned by the DataMapper::Model#all
  # method.
  class Collection < LazyArray
    include Assertions

    ##
    # The Query scope
    #
    # @return [DataMapper::Query] the Query the Collection is scoped with
    #
    # @api semipublic
    attr_reader :query

    ##
    # The associated Repository
    #
    # @return [DataMapper::Repository] the Repository the Collection is
    #   associated with
    #
    # @api semipublic
    def repository
      query.repository
    end

    ##
    # Initialize a Resource and add it to the Collection
    #
    # This should load a Resource, add it to the Collection and relate
    # the it to the Collection.
    #
    # @param [Array] values the values for the Resource
    #
    # @return [DataMapper::Resource] the loaded Resource
    #
    # @api semipublic
    def load(values)
      add(model.load(values, query))
    end

    ##
    # Reload the Collection from the data source
    #
    # @param [Hash] query further restrict results with query
    #
    # @return [DataMapper::Collection] self
    #
    # @api public
    def reload(query = {})
      repository_name = repository.name
      @query = scoped_query(query)
      @query.update(:fields => @query.fields | model.key(repository_name))

      # specify a Repository to ensure the Identity Map from the existing
      # query's Repository isn't used, and the resources are reloaded
      # properly.
      # TODO: update Query#update to overwrite it's @repository with the "other" repository
      replace(all(:repository => Repository.new(repository_name), :reload => true))
    end

    ##
    # Lookup a Resource in the Collection by key
    #
    # This looksup a Resource by key, typecasting the key to the
    # proper object if necessary.
    #
    # @param [Array] key keys which uniquely identify a resource in the
    #   Collection
    #
    # @return [DataMapper::Resource, NilClass] the Resource which
    #   matches the supplied key
    #
    # @api public
    def get(*key)
      key = model.typecast_key(key)
      if loaded?
        # find indexed resource
        @cache[key]
      elsif query.limit || query.offset > 0
        # current query is exclusive, find resource within the set

        # TODO: use a subquery to retrieve the Collection and then match
        #   it up against the key.  This will require some changes to
        #   how subqueries are generated, since the key may be a
        #   composite key.  In the case of DO adapters, it means subselects
        #   like the form "(a, b) IN(SELECT a,b FROM ...)", which will
        #   require making it so the Query condition key can be a
        #   Property or an Array of Property objects

        # use the brute force approach until subquery lookups work
        lazy_load
        get(*key)
      else
        # current query is all inclusive, lookup using normal approach
        first(model.to_query(repository, key))
      end
    end

    ##
    # Lookup a Resource in the Collection by key, raising an exception if not found
    #
    # This looksup a Resource by key, typecasting the key to the
    # proper object if necessary.
    #
    # @param [Array] key keys which uniquely identify a resource in the
    #   Collection
    #
    # @return [DataMapper::Resource, NilClass] the Resource which
    #   matches the supplied key
    #
    # @raise [ObjectNotFoundError] Resource could not be found by key
    #
    # @api public
    def get!(*key)
      get(*key) || raise(ObjectNotFoundError, "Could not find #{model.name} with key #{key.inspect} in collection")
    end

    ##
    # Returns a new Collection scoped by the query
    #
    # This returns a new Collection scoped relative to the current
    # Collection.
    #
    # @param [Hash] (optional) query parameters to scope results with
    #
    # @return [DataMapper::Collection] a Collection scoped by the query
    #
    # @api public
    def all(query = nil)
      # TODO: this shouldn't be a kicker if scoped_query() is called
      if query.nil? || query == self.query
        self
      else
        query = scoped_query(query)
        query.repository.read_many(query)
      end
    end

    ##
    # Return the first Resource or the first N Resources in the Collection with an optional query
    #
    # When there are no arguments, return the first Resource in the
    # Collection.  When the first argument is an Integer, return a
    # Collection containing the first N Resources.  When the last
    # (optional) argument is a Hash scope the results to the query.
    #
    # @param [Integer] limit (optional) limit the returned Collection
    #   to a specific number of entries
    # @param [Hash] query (optional) scope the returned Resource or
    #   Collection to the supplied query
    #
    # @return [DataMapper::Resource, DataMapper::Collection] The
    #   first resource in the entries of this collection, or
    #   a new collection whose query has been merged
    #
    # @api public
    def first(*args)
      with_query = args.last.respond_to?(:merge)

      limit = if args.first.kind_of?(Integer)
        args.first
      end

      query = with_query ? args.last : {}
      query = scoped_query(query.merge(:limit => limit || 1))

      if !with_query && lazy_possible?(head, *args)
        if limit
          self.class.new(query, head.first(limit))
        else
          relate_resource(head.first)
        end
      elsif !with_query && loaded?
        if limit
          self.class.new(query, super(limit))
        else
          relate_resource(super)
        end
      else
        if limit
          query.repository.read_many(query)
        else
          relate_resource(query.repository.read_one(query))
        end
      end
    end

    ##
    # Return the last Resource or the last N Resources in the Collection with an optional query
    #
    # When there are no arguments, return the last Resource in the
    # Collection.  When the first argument is an Integer, return a
    # Collection containing the last N Resources.  When the last
    # (optional) argument is a Hash scope the results to the query.
    #
    # @param [Integer] limit (optional) limit the returned Collection
    #   to a specific number of entries
    # @param [Hash] query (optional) scope the returned Resource or
    #   Collection to the supplied query
    #
    # @return [DataMapper::Resource, DataMapper::Collection] The
    #   last resource in the entries of this collection, or
    #   a new collection whose query has been merged
    #
    # @api public
    def last(*args)
      with_query = args.last.respond_to?(:merge)

      limit = if args.first.kind_of?(Integer)
        args.first
      end

      query = with_query ? args.last : {}
      query = scoped_query(query.merge(:limit => limit || 1)).reverse

      # tell the Query to prepend each result from the adapter
      query.update(:add_reversed => !query.add_reversed?)

      if !with_query && lazy_possible?(tail, *args)
        if limit
          self.class.new(query, tail.last(limit))
        else
          relate_resource(tail.last)
        end
      elsif !with_query && loaded?
        if limit
          self.class.new(query, super(limit))
        else
          relate_resource(super)
        end
      else
        if limit
          query.repository.read_many(query)
        else
          relate_resource(query.repository.read_one(query))
        end
      end
    end

    ##
    # Lookup a Resource from the Collection by index
    #
    # @param [Integer] index index of the Resource in the Collection
    #
    # @return [DataMapper::Resource, NilClass] the Resource which
    #   matches the supplied offset
    #
    # @api public
    def at(index)
      if loaded?
        return super
      elsif index >= 0
        first(:offset => index)
      else
        last(:offset => index.abs - 1)
      end
    end

    ##
    # Simulates Array#slice and returns a new Collection
    # whose query has a new offset or limit according to the
    # arguments provided.
    #
    # If you provide a range, the min is used as the offset
    # and the max minues the offset is used as the limit.
    #
    # @param [Integer, Array(Integer), Range] args the offset,
    # offset and limit, or range indicating offsets and limits
    #
    # @return [DataMapper::Resource, DataMapper::Collection]
    #   The entry which resides at that offset and limit,
    #   or a new Collection object with the set limits and offset
    #
    # @raise [ArgumentError] "arguments may be 1 or 2 Integers,
    #   or 1 Range object, was: #{args.inspect}"
    #
    # @api public
    def slice(*args)
      if args.size == 1 && args.first.kind_of?(Integer)
        return at(args.first)
      end

      if args.size == 2 && args.first.kind_of?(Integer) && args.last.kind_of?(Integer)
        offset, limit = args
      elsif args.size == 1 && args.first.kind_of?(Range)
        range  = args.first
        offset = range.first
        limit  = range.last - offset
        limit += 1 unless range.exclude_end?
      else
        raise ArgumentError, "arguments may be 1 or 2 Integers, or 1 Range object, was: #{args.inspect}", caller
      end

      all(:offset => offset, :limit => limit)
    end

    alias [] slice

    # TODO: document
    # @api public
    def slice!(*args)
      orphaned = super

      # Workaround for Ruby <= 1.8.6
      compact! if RUBY_VERSION <= '1.8.6'

      if orphaned.kind_of?(Array)
        orphaned.each { |r| orphan_resource(r) }
      else
        orphan_resource(orphaned)
      end
    end

    ##
    # Return the Collection sorted in reverse
    #
    # @return [DataMapper::Collection]
    #
    # @api public
    def reverse
      if loaded?
        self.class.new(query.reverse, super)
      else
        all(query.reverse)
      end
    end

    ##
    # Invoke the block for each resource and replace it the return value
    #
    # @yield [DataMapper::Resource] Each resource in the collection
    #
    # @return [DataMapper::Collection] self
    #
    # @api public
    def collect!
      super { |r| relate_resource(yield(orphan_resource(r))) }
    end

    alias map! collect!

    ##
    # Append one Resource to the Collection
    #
    # This should append a Resource to the Collection and relate it
    # to the Collection.
    #
    # @return [DataMapper::Collection] self
    #
    # @api public
    def <<(resource)
      relate_resource(resource)
      super
    end

    ##
    # Appends the resources to self
    #
    # @param [Enumerable] resources The resources to append to the collection
    #
    # @return [DataMapper::Collection] self
    #
    # @api public
    def concat(resources)
      resources.each { |r| relate_resource(r) }
      super
    end

    ##
    # Inserts the Resources before the Resource at the index (which may be negative).
    #
    # @param [Integer] index The index to insert the Resources before
    # @param [Enumerable] *resources The Resources to insert
    #
    # @return [DataMapper::Collection] self
    #
    # @api public
    def insert(index, *resources)
      resources.each { |r| relate_resource(r) }
      super
    end

    ##
    # Append one or more Resources to the Collection
    #
    # This should append one or more Resources to the Collection and
    # relate each to the Collection.
    #
    # @param [Enumerable] *resources The Resources to append
    #
    # @return [DataMapper::Collection] self
    #
    # @api public
    def push(*resources)
      resources.each { |r| relate_resource(r) }
      super
    end

    ##
    # Prepend one or more Resources to the Collection
    #
    # This should prepend one or more Resources to the Collection and
    # relate each to the Collection.
    #
    # @param [Enumerable] *resources The Resources to prepend
    #
    # @return [DataMapper::Collection] self
    #
    # @api public
    def unshift(*resources)
      resources.each { |r| relate_resource(r) }
      super
    end

    ##
    # Replace the Resources within the Collection
    #
    # @return [DataMapper::Collection] self
    #
    # @api public
    def replace(other)
      if loaded?
        each { |r| orphan_resource(r) }
      end
      other.each { |r| relate_resource(r) }
      super
    end

    # TODO: document
    # @api public
    def pop
      orphan_resource(super)
    end

    # TODO: document
    # @api public
    def shift
      orphan_resource(super)
    end

    ##
    # Remove Resource from the Collection
    #
    # This should remove an included Resource from the Collection and
    # orphan it from the Collection.  If the Resource is within the
    # Collection it should return nil.
    #
    # @param [DataMapper::Resource] resource the Resource to remove from
    #   the Collection
    #
    # @return [DataMapper::Resource, NilClass] the matching Resource if
    #   it is within the Collection
    #
    # @api public
    def delete(resource)
      orphan_resource(super)
    end

    ##
    # Remove Resource from the Collection by index
    #
    # This should remove the Resource from the Collection at a given
    # index and orphan it from the Collection.  If the index is out of
    # range return nil.
    #
    # @param [Integer] index the index of the Resource to remove from
    #   the Collection
    #
    # @return [DataMapper::Resource, NilClass] the matching Resource if
    #   it is within the Collection
    #
    # @api public
    def delete_at(index)
      orphan_resource(super)
    end

    ##
    # Deletes every Resource for which block evaluates to true.
    #
    # @yield [DataMapper::Resource] Each resource in the collection
    #
    # @return [DataMapper::Collection] self
    #
    # @api public
    def delete_if
      super { |r| yield(r) && orphan_resource(r) }
    end

    # TODO: document
    # @api public
    def reject!
      super { |r| yield(r) && orphan_resource(r) }
    end

    ##
    # Makes the Collection empty
    #
    # This should make the Collection empty, and orphan each removed
    # Resource from the Collection.
    #
    # @return [DataMapper::Collection] self
    #
    # @api public
    def clear
      if loaded?
        each { |r| orphan_resource(r) }
      end
      super
    end

    ##
    # Builds a new Resource and appends it to the Collection
    #
    # @param [Hash] attributes attributes which
    #   the new resource should have.
    #
    # @return [DataMapper::Resource] a new Resource
    #
    # @api public
    def build(attributes = {})
      repository.scope do
        resource = model.new(default_attributes.update(attributes))
        self << resource
        resource
      end
    end

    ##
    # Creates a new Resource, saves it, and appends it to the Collection
    #
    # @param [Hash] attributes attributes which
    #   the new resource should have.
    #
    # @return [DataMapper::Resource] a saved Resource
    #
    # @api public
    def create(attributes = {})
      repository.scope do
        resource = model.create(default_attributes.update(attributes))
        self << resource unless resource.new_record?
        resource
      end
    end

    ##
    # Update every Resource in the Collection (TODO)
    #
    #   Person.all(:age.gte => 21).update!(:allow_beer => true)
    #
    # @param [Hash] attributes attributes to update
    #
    # @return [TrueClass, FalseClass]
    #   TrueClass indicates that all entries were affected
    #   FalseClass indicates that some entries were affected
    #
    # @api public
    def update(attributes = {})
      raise NotImplementedError, 'update *with* validations has not be written yet, try update!'
    end

    ##
    # Update every Resource in the Collection bypassing validation
    #
    #   Person.all(:age.gte => 21).update!(:allow_beer => true)
    #
    # @param [Hash] attributes attributes to update
    #
    # @return [TrueClass, FalseClass]
    #   TrueClass indicates that all entries were affected
    #   FalseClass indicates that some entries were affected
    #
    # @api public
    def update!(attributes = {})
      # TODO: delegate to Model.update
      unless attributes.empty?
        dirty_attributes = {}

        model.properties(repository.name).each do |property|
          next unless attributes.has_key?(property.name)
          dirty_attributes[property] = attributes[property.name]
        end

        changed = repository.update(dirty_attributes, scoped_query)

        if loaded? && changed > 0
          each { |r| r.attributes = attributes }
        end
      end

      true
    end

    ##
    # Remove all Resources from the datasource (TODO)
    #
    # This performs a deletion of each Resource in the Collection from
    # the datasource and clears the Collection.
    #
    # @return [TrueClass, FalseClass]
    #   TrueClass indicates that all entries were affected
    #   FalseClass indicates that not all entries were affected
    #
    # @api public
    def destroy
      raise NotImplementedError, 'destroy *with* validations has not be written yet, try destroy!'
    end

    ##
    # Remove all Resources from the datasource bypassing validation
    #
    # This performs a deletion of each Resource in the Collection from
    # the datasource and clears the Collection while skipping foreign
    # key validation (TODO).
    #
    # @return [TrueClass, FalseClass]
    #   TrueClass indicates that all entries were affected
    #   FalseClass indicates that not all entries were affected
    #
    # @api public
    def destroy!
      # TODO: delegate to Model.destroy
      deleted = repository.delete(scoped_query)

      if loaded? && deleted > 0
        each do |r|
          # TODO: move this logic to a semipublic method in Resource
          r.instance_variable_set(:@new_record, true)
          identity_map.delete(r.key)
          r.dirty_attributes.clear

          model.properties(repository.name).each do |property|
            next unless r.attribute_loaded?(property.name)
            r.dirty_attributes[property] = property.get(r)
          end
        end
      end

      clear

      true
    end

    ##
    # @return [DataMapper::PropertySet] The set of properties this
    #   query will be retrieving
    #
    # @api semipublic
    def properties
      PropertySet.new(query.fields)
    end

    ##
    # @return [Hash] The model's relationships, mapping the name to the
    #   DataMapper::Associations::Relationship object
    #
    # @api semipublic
    def relationships
      model.relationships(repository.name)
    end

    ##
    # Returns default values to initialize new Resources in the Collection
    #
    # @return [Hash] The default attributes for DataMapper::Collection#create
    #
    # @api semipublic
    def default_attributes
      default_attributes = {}
      query.conditions.each do |tuple|
        operator, property, bind_value = *tuple

        next unless operator == :eql &&
          property.kind_of?(DataMapper::Property) &&
          ![ Array, Range ].any? { |k| bind_value.kind_of?(k) }
          !model.key(repository.name).include?(property)

        default_attributes[property.name] = bind_value
      end
      default_attributes
    end

    ##
    # check to see if collection can respond to the method
    #
    # @param [Symbol] method  method to check in the object
    # @param [FalseClass, TrueClass] include_private  if set to true,
    #   collection will check private methods
    #
    # @return [TrueClass, FalseClass]
    #   TrueClass indicates the method can be responded to by the Collection
    #   FalseClass indicates the method can not be responded to by the Collection
    #
    # @api public
    def respond_to?(method, include_private = false)
      super || model.public_methods(false).include?(method.to_s) || relationships.has_key?(method)
    end

    ##
    # Returns true if the other object is identical to self
    #
    # @param [DataMapper::Collection] other Another Collection obejct
    #
    # @return [TrueClass, FalseClass] true if the obejcts are identical
    #
    # @api public
    def equal?(other)
      object_id == other.object_id
    end

    protected

    # TODO: document
    # @api private
    def model
      query.model
    end

    private

    ##
    # Initializes a new DataMapper::Collection identified by the query.
    #
    # @param [DataMapper::Query] query Scope the results of the Collection
    # @param [Enumerable] resources (optional) A list of resources to
    #   initialize the Collection with
    #
    # @return [DataMapper::Collection] self
    #
    # @api public
    def initialize(query, resources = [])
      assert_kind_of 'query', query, Query

      @query = query
      @cache = {}

      super()

      if resources.any?
        replace(resources)
      elsif block_given?
        load_with { |c| yield(c) }
      end
    end

    # TODO: document
    # @api private
    def add(resource)
      query.add_reversed? ? unshift(resource) : push(resource)
      resource
    end

    # TODO: document
    # @api private
    def relate_resource(resource)
      return unless resource
      resource.collection = self
      @cache[resource.key] = resource
      resource
    end

    # TODO: document
    # @api private
    def orphan_resource(resource)
      return unless resource
      if resource.collection.object_id == self.object_id
        resource.collection = nil
      end
      @cache.delete(resource.key)
      resource
    end

    # TODO: document
    # @api private
    # TODO: move the logic to create relative query into DataMapper::Query
    def scoped_query(query = self.query)
      assert_kind_of 'query', query, Query, Hash

      if query.kind_of?(Hash)
        repository = if query.has_key?(:repository)
          query.delete(:repository)
        else
          self.repository
        end
        query = Query.new(repository, model, query)
      end

      if query == self.query
        return query
      end

      if query.limit || query.offset > 0
        set_relative_position(query)
      end

      self.query.merge(query)
    end

    # TODO: document
    # @api private
    def identity_map
      repository.identity_map(model)
    end

    # TODO: document
    # @api private
    def set_relative_position(query)
      if query.offset == 0 && query.limit && self.query.limit && query.limit <= self.query.limit
        return
      end

      first_pos = self.query.offset + query.offset

      if self.query.limit
        last_pos = self.query.offset + self.query.limit
      end

      if limit = query.limit
        if last_pos.nil? || first_pos + limit < last_pos
          last_pos = first_pos + limit
        end
      end

      if last_pos && first_pos >= last_pos
        raise 'outside range'  # TODO: raise a proper exception object
      end

      query.update(:offset => first_pos)

      if last_pos
        query.update(:limit => last_pos - first_pos)
      end
    end

    ##
    # Delegates to Model, Relationships or the superclass (LazyArray)
    #
    # When this receives a method that belongs to the Model the
    # Collection is scoped to, it will execute the method within the
    # same scope as the Collection and return the results.
    #
    # When this receives a method that is a relationship the Model has
    # defined, it will execute the association method within the same
    # scope as the Collection and return the results.
    #
    # Otherwise this method will delegate to a method in the superclass
    # (LazyArray) and return the results.
    #
    # @api public
    def method_missing(method, *args, &block)
      # TODO: split up each logic branch into a separate method

      if model.public_methods(false).include?(method.to_s)
        model.send(:with_scope, query) do
          model.send(method, *args, &block)
        end
      elsif relationship = relationships[method]
        klass = model == relationship.child_model ? relationship.parent_model : relationship.child_model

        # TODO: when self.query includes an offset/limit use it as a
        # subquery to scope the results rather than a join

        query = Query.new(repository, klass)
        query.conditions.push(*self.query.conditions)
        query.update(relationship.query)
        if args.last.kind_of?(Hash)
          query.update(args.pop)
        end

        query.update(
          :fields => klass.properties(repository.name).defaults,
          :links  => [ relationship ] + self.query.links
        )

        klass.all(query, &block)
      else
        super
      end
    end
  end # class Collection
end # module DataMapper
