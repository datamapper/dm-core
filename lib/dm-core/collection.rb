module DataMapper
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
      @query = scoped_query(query)
      @query.update(:fields => @query.fields | @key_properties)
      replace(all(:reload => true))
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
        # find indexed resource (create index first if it does not exist)
        each {|r| @cache[r.key] = r } if @cache.empty?
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
    # Return a Collection scoped by the query
    #
    # @param [Hash] (optional) query parameters to scope results with
    #
    # @return [DataMapper::Collection] a Collection scoped by the query
    #
    # @api public
    def all(query = {})
      # TODO: this shouldn't be a kicker if scoped_query() is called
      return self if query.kind_of?(Hash) ? query.empty? : query == self.query
      query = scoped_query(query)
      query.repository.read_many(query)
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
      # TODO: this shouldn't be a kicker if scoped_query() is called
      if loaded?
        if args.empty?
          return super
        elsif args.size == 1 && args.first.kind_of?(Integer)
          limit = args.shift
          return self.class.new(scoped_query(:limit => limit)) { |c| c.replace(super(limit)) }
        end
      end

      query = args.last.respond_to?(:merge) ? args.pop : {}
      query = scoped_query(query.merge(:limit => args.first || 1))

      if args.any?
        query.repository.read_many(query)
      else
        query.repository.read_one(query)
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
    # TODO: fix gaurd clause to match first()'s
    def last(*args)
      return super if loaded? && args.empty?

      reversed = reverse

      # tell the Collection to reverse the order of the
      # results coming out of the adapter
      reversed.query.add_reversed = !query.add_reversed?

      reversed.first(*args)
    end

    ##
    # Lookup a Resource from the Collection by index
    #
    # @param [Integer] offset index of the Resource in the Collection
    #
    # @return [DataMapper::Resource, NilClass] the Resource which
    #   matches the supplied offset
    #
    # @api public
    # TODO: rename param "index" to match Array docs
    def at(offset)
      return super if loaded?
      offset >= 0 ? first(:offset => offset) : last(:offset => offset.abs - 1)
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
      return at(args.first) if args.size == 1 && args.first.kind_of?(Integer)

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

    ##
    # Return the Collection sorted in reverse
    #
    # @return [DataMapper::Collection]
    #
    # @api public
    def reverse
      all(self.query.reverse)
    end

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
      super
      relate_resource(resource)
      self
    end

    ##
    # Append one or more Resources to the Collection
    #
    # This should append one or more Resources to the Collection and
    # relate each to the Collection.
    #
    # @return [DataMapper::Collection] self
    #
    # @api public
    def push(*resources)
      super
      resources.each { |resource| relate_resource(resource) }
      self
    end

    ##
    # Prepend one or more Resources to the Collection
    #
    # @return [DataMapper::Collection] self
    #
    # @api public
    def unshift(*resources)
      super
      resources.each { |resource| relate_resource(resource) }
      self
    end

    ##
    # Replace the Resources within the Collection
    #
    # @return [DataMapper::Collection] self
    #
    # @api public
    def replace(other)
      if loaded?
        each { |resource| orphan_resource(resource) }
      end
      super
      other.each { |resource| relate_resource(resource) }
      self
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
        each { |resource| orphan_resource(resource) }
      end
      super
      self
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
        resource = model.new(default_attributes.merge(attributes))
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
        resource = model.create(default_attributes.merge(attributes))
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
    # @param [FalseClass, TrueClass] reload if set to true, collection
    #   will have loaded resources reflect updates.
    #
    # @return [TrueClass, FalseClass]
    #   TrueClass indicates that all entries were affected
    #   FalseClass indicates that some entries were affected
    #
    # @api public
    # TODO: make it so the Collection is always reloaded after update
    def update(attributes = {}, preload = false)
      raise NotImplementedError, 'update *with* validations has not be written yet, try update!'
    end

    ##
    # Update every Resource in the Collection bypassing validation
    #
    #   Person.all(:age.gte => 21).update!(:allow_beer => true)
    #
    # @param [Hash] attributes attributes to update
    # @param [FalseClass, TrueClass] reload if set to true, collection
    #   will have loaded resources reflect updates.
    #
    # @return [TrueClass, FalseClass]
    #   TrueClass indicates that all entries were affected
    #   FalseClass indicates that some entries were affected
    #
    # @api public
    # TODO: make it so the Collection is always reloaded after update
    # TODO: make it so update! returns true always
    def update!(attributes = {}, reload = false)
      # TODO: delegate to Model.update
      return true if attributes.empty?

      dirty_attributes = {}

      model.properties(repository.name).slice(*attributes.keys).each do |property|
        dirty_attributes[property] = attributes[property.name] if property
      end

      # this should never be done on update! even if collection is loaded. or?
      # each { |resource| resource.attributes = attributes } if loaded?

      changes = repository.update(dirty_attributes, scoped_query)

      # need to decide if this should be done in update!
      query.update(attributes)

      if identity_map.any? && reload
        reload_query = @key_properties.zip(identity_map.keys.transpose).to_hash
        model.all(reload_query.merge(attributes)).reload(:fields => attributes.keys)
      end

      # this should return true if there are any changes at all. as it skips validations
      # the only way it could be fewer changes is if some resources already was updated.
      # that should not return false? true = 'now all objects have these new values'
      return loaded? ? changes == size : changes > 0
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
      if loaded?
        return false unless repository.delete(scoped_query) == size

        each do |resource|
          resource.instance_variable_set(:@new_record, true)
          identity_map.delete(resource.key)
          resource.dirty_attributes.clear

          model.properties(repository.name).each do |property|
            next unless resource.attribute_loaded?(property.name)
            resource.dirty_attributes[property] = property.get(resource)
          end
        end
      else
        return false unless repository.delete(scoped_query) > 0
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
    # @return [DataMapper::Relationship] The model's relationships
    #
    # @api semipublic
    def relationships
      model.relationships(repository.name)
    end

    ##
    # default values to use when creating a Resource within the Collection
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
          !@key_properties.include?(property)

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

    protected

    # TODO: document
    # @api semipublic
    def model
      query.model
    end

    private

    # TODO: document
    # @api public
    def initialize(query, &block)
      assert_kind_of 'query', query, Query

      unless block_given?
        # It can be helpful (relationship.rb: 112-13, used for SEL) to have a non-lazy Collection.
        block = lambda {}
      end

      @query          = query
      @key_properties = model.key(repository.name)
      @cache          = {}

      super()

      load_with(&block)
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
      resource.collection = nil if resource.collection.object_id == self.object_id
      @cache.delete(resource.key)
      resource
    end

    # TODO: document
    # @api private
    # TODO: move the logic to create relative query into DataMapper::Query
    def scoped_query(query = self.query)
      assert_kind_of 'query', query, Query, Hash

      query.update(keys) if loaded?

      return self.query if query == self.query

      query = if query.kind_of?(Hash)
        Query.new(query.has_key?(:repository) ? query.delete(:repository) : self.repository, model, query)
      else
        query
      end

      if query.limit || query.offset > 0
        set_relative_position(query)
      end

      self.query.merge(query)
    end

    # TODO: document
    # @api private
    def keys
      keys = map {|r| r.key }
      keys.any? ? @key_properties.zip(keys.transpose).to_hash : {}
    end

    # TODO: document
    # @api private
    def identity_map
      repository.identity_map(model)
    end

    # TODO: document
    # @api private
    def set_relative_position(query)
      return if query == self.query

      if query.offset == 0
        return if !query.limit.nil? && !self.query.limit.nil? && query.limit <= self.query.limit
        return if  query.limit.nil? &&  self.query.limit.nil?
      end

      first_pos = self.query.offset + query.offset
      last_pos  = self.query.offset + self.query.limit if self.query.limit

      if limit = query.limit
        if last_pos.nil? || first_pos + limit < last_pos
          last_pos = first_pos + limit
        end
      end

      if last_pos && first_pos >= last_pos
        raise 'outside range'  # TODO: raise a proper exception object
      end

      query.update(:offset => first_pos)
      query.update(:limit => last_pos - first_pos) if last_pos
    end

    # TODO: document
    # @api public
    # TODO: split up each logic branch into a separate method
    def method_missing(method, *args, &block)
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
        query.update(args.pop) if args.last.kind_of?(Hash)

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
