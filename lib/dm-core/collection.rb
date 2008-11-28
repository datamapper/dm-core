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
    # Returns the Query the Collection is scoped with
    #
    # @return [DataMapper::Query] the Query the Collection is scoped with
    #
    # @api semipublic
    attr_reader :query

    ##
    # Returns the Repository
    #
    # @return [DataMapper::Repository]
    #   the Repository this Collection is associated with
    #
    # @api semipublic
    def repository
      query.repository
    end

    ##
    # Initializes a Resource and adds it to the Collection
    #
    # This should load a Resource, then add and relate it to the Collection.
    #
    # @param [Enumerable] values the values for the Resource
    #
    # @return [DataMapper::Resource] the loaded Resource
    #
    # @api semipublic
    def load(values)
      resource = model.load(values, query)

      unless (head && head.include?(resource)) || (tail && tail.include?(resource)) || @orphans.include?(resource)
        query.add_reversed? ? unshift(resource) : push(resource)
      end

      resource
    end

    ##
    # Reloads the Collection from the repository.
    # 
    # If +query+ is provided, updates this Collection's query with its conditions
    #
    #   cars_from_91 = Cars.all(:year_manufactured.eql => 1991)
    #   cars_from_91.first.year_manufactured = 2001   # note: not saved
    #   cars_from_91.reload
    #   cars_from_91.first.year                       #=> 1991
    #
    # @param [Query, Hash] query (optional)
    #   further restrict results with query
    #
    # @return [DataMapper::Collection] self
    #
    # @api public
    def reload(query = nil)
      if query.kind_of?(Hash) && query.any?
        @query = Query.new(repository, model, query_to_hash(self.query).merge(query))
      elsif query.kind_of?(Query)
        @query = query
      end

      # XXX: when not loaded, should the behavior change?

      # update query fields to always include the model key
      @query.update(:fields => @query.fields | model.key(repository.name))

      # specify the Query explicitly so that Collection#all does not
      # perform a relative query
      query = Query.new(repository, model, query_to_hash(self.query).update(:reload => true))

      # load a collection and replace the current collection with the results
      replace(all(query))
    end

    ##
    # Lookup a Resource in the Collection by key
    #
    # This looksup a Resource by key, typecasting the key to the
    # proper object if necessary.
    #
    #   toyotas = Cars.all(:manufacturer => "Toyota")
    #   toyo = Cars.first(:manufacturer => "Toyota")
    #   toyotas.get(toyo.id) == toyo                  #=> true
    #
    # @param [Enumerable] *key
    #   keys which uniquely identify a resource in the Collection
    #
    # @return [DataMapper::Resource]
    #   Resource which matches the supplied key
    # @return [NilClass]
    #   No Resource matches the supplied key
    #
    # @api public
    def get(*key)
      key = model.typecast_key(key)
      return if key.any? { |v| v.blank? }

      if resource = @cache[key]
        # find cached resource
        resource
      elsif !loaded? && (query.limit || query.offset > 0)
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
        @cache[key]
      else
        # current query is all inclusive, lookup using normal approach
        first(model.key(repository.name).zip(key).to_hash)
      end
    end

    ##
    # Lookup a Resource in the Collection by key, raising an exception if not found
    #
    # This looksup a Resource by key, typecasting the key to the
    # proper object if necessary.
    #
    # @param [Enumerable] *key
    #   keys which uniquely identify a resource in the Collection
    #
    # @return [DataMapper::Resource]
    #   Resource which matches the supplied key
    # @return [NilClass]
    #   No Resource matches the supplied key
    #
    # @raise [ObjectNotFoundError] Resource could not be found by key
    #
    # @api public
    def get!(*key)
      get(*key) || raise(ObjectNotFoundError, "Could not find #{model.name} with key #{key.inspect} in collection")
    end

    ##
    # Returns a new Collection optionally scoped by +query+
    #
    # This returns a new Collection scoped relative to the current
    # Collection.
    #
    #   cars_from_91 = Cars.all(:year_manufactured.eql => 1991)
    #   toyotas_91 = cars_from_91.all(:manufacturer => "Toyota")
    #   toyotas_91.all? { |c| c.year_manufactured == 1991 }       #=> true
    #   toyotas_91.all? { |c| c.manufacturer == "Toyota" }        #=> true
    #
    # If +query+ is a Hash, results will be found by merging +query+ with this Collection's query. 
    # If +query+ is a Query, results will be found using +query+ as an absolute query.
    #   
    # @param [Hash, Query] query (optional)
    #   parameters to scope results with.
    #
    # @return [DataMapper::Collection]
    #   Collection scoped by +query+.
    #
    # @api public
    def all(query = nil)
      query = scoped_query(query)

      if query == self.query
        self
      else
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
    # @param [Integer] limit (optional)
    #   limit the returned Collection to a specific number of entries
    # @param [Hash] query (optional)
    #   scope the returned Resource or Collection to the supplied query
    #
    # @return [DataMapper::Resource, DataMapper::Collection]
    #   The first resource in the entries of this collection,
    #   or a new collection whose query has been merged
    #
    # @api public
    def first(*args)
      last_arg = args.last

      limit      = args.first if args.first.kind_of?(Integer)
      with_query = last_arg.respond_to?(:merge) && !last_arg.blank?

      query = with_query ? last_arg : {}
      query = scoped_query(query.merge(:limit => limit || 1))

      if !with_query && (loaded? || lazy_possible?(head, limit || 1))
        if limit
          self.class.new(query, super(limit))
        else
          super()
        end
      else
        if limit
          all(query)
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
    # @param [Integer] limit (optional)
    #   limit the returned Collection to a specific number of entries
    # @param [Hash] query (optional)
    #   scope the returned Resource or Collection to the supplied query
    #
    # @return [DataMapper::Resource, DataMapper::Collection]
    #   The last resource in the entries of this collection,
    #   or a new collection whose query has been merged
    #
    # @api public
    def last(*args)
      last_arg = args.last

      limit      = args.first if args.first.kind_of?(Integer)
      with_query = last_arg.respond_to?(:merge) && !last_arg.blank?

      query = with_query ? last_arg : {}
      query = scoped_query(query.merge(:limit => limit || 1)).reverse

      # tell the Query to prepend each result from the adapter
      query.update(:add_reversed => !query.add_reversed?)

      if !with_query && (loaded? || lazy_possible?(tail, limit || 1))
        if limit
          self.class.new(query, super(limit))
        else
          super()
        end
      else
        if limit
          all(query)
        else
          relate_resource(query.repository.read_one(query))
        end
      end
    end

    ##
    # Lookup a Resource from the Collection by offset
    #
    # @param [Integer] offset
    #   offset of the Resource in the Collection
    #
    # @return [DataMapper::Resource]
    #   Resource which matches the supplied offset
    # @return [NilClass]
    #   No Resource matches the supplied offset
    #
    # @api public
    def at(offset)
      if loaded? || (offset >= 0 ? lazy_possible?(head, offset + 1) : lazy_possible?(tail, offset.abs))
        super
      elsif offset >= 0
        first(:offset => offset)
      else
        last(:offset => offset.abs - 1)
      end
    end

    ##
    # Access LazyArray#slice directly
    #
    # Collection#[]= uses this to bypass Collection#slice and access
    # the resources directly so that it can orphan them properly.
    #
    # @api private
    alias superclass_slice slice
    private :superclass_slice

    ##
    # Simulates Array#slice and returns a new Collection
    # whose query has a new offset or limit according to the
    # arguments provided.
    #
    # If you provide a range, the min is used as the offset
    # and the max minues the offset is used as the limit.
    #
    # @param [Integer, Array(Integer), Range] *args
    #   the offset, offset and limit, or range indicating first and last position
    #
    # @return [DataMapper::Resource, DataMapper::Collection, NilClass]
    #   The entry which resides at that offset and limit,
    #   or a new Collection object with the set limits and offset
    # @return [NilClass]
    #   The offset (or starting offset) is out of range
    #
    # @raise [ArgumentError] "arguments may be 1 or 2 Integers,
    #   or 1 Range object, was: #{args.inspect}"
    #
    # @api public
    def [](*args)
      offset, limit = extract_slice_arguments(*args)

      if limit.nil?
        return at(offset)
      end

      query = if offset >= 0
        scoped_query(:offset => offset, :limit => limit)
      else
        query = scoped_query(:offset => (limit + offset).abs, :limit => limit).reverse

        # tell the Query to prepend each result from the adapter
        query.update(:add_reversed => !query.add_reversed?)
      end

      if sliced = super
        self.class.new(query, sliced)
      else
        nil
      end
    end

    alias slice []

    ##
    # Deletes and Returns the Resources given by an offset or a Range
    #
    # @param [Integer, Array(Integer), Range] *args
    #   the offset, offset and limit, or range indicating first and last position
    #
    # @return [DataMapper::Resource, DataMapper::Collection]
    #   The entry which resides at that offset and limit, or
    #   a new Collection object with the set limits and offset
    # @return [DataMapper::Resource, DataMapper::Collection, NilClass]
    #   The offset is out of range.
    #
    # @api public
    def slice!(*args)
      # lazy load the collection, and remove the matching entries
      orphaned = orphan_resources(super)

      # Workaround for Ruby <= 1.8.6
      compact! if RUBY_VERSION <= '1.8.6'

      unless orphaned.kind_of?(Enumerable)
        return orphaned
      end

      offset, limit = extract_slice_arguments(*args)

      query = if offset >= 0
        scoped_query(:offset => offset, :limit => limit)
      else
        query = scoped_query(:offset => (limit + offset).abs, :limit => limit).reverse

        # tell the Query to prepend each result from the adapter
        query.update(:add_reversed => !query.add_reversed?)
      end

      self.class.new(query, orphaned)
    end

    ##
    # Splice a list of Resources at a given offset or range
    #
    # When nil is provided instead of a Resource or a list of Resources
    # this will remove all of the Resources at the specified position.
    #
    # @param [Integer, Array(Integer), Range] *args
    #   The offset, offset and limit, or range indicating first and last position.
    #   The last argument may be a Resource, a list of Resources or nil.
    #
    # @return [DataMapper::Resource, Enumerable]
    #   the Resource or list of Resources that was spliced into the Collection
    # @return [NilClass]
    #   If nil was used to delete the entries
    #
    # @api public
    def []=(*args)
      # orphan resources being replaced
      orphan_resources(superclass_slice(*args[0..-2]))

      # relate new resources
      relate_resources(super)
    end

    alias splice []=

    ##
    # Return the Collection sorted in reverse
    #
    # @return [DataMapper::Collection]
    #   Collection equal to +self+ but ordered in reverse.
    #
    # @api public
    def reverse
      reversed = super
      reversed.instance_variable_set(:@query, query.reverse)
      reversed
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
    # Append one Resource to the Collection and relate it
    #
    # @param [DataMapper::Resource] resource
    #   the resource to add to this collection
    #
    # @return [DataMapper::Collection] self
    #
    # @api public
    def <<(resource)
      relate_resource(resource)
      super
    end

    alias add <<

    ##
    # Appends the resources to self
    #
    # @param [Enumerable] resources
    #   List of Resources to append to the collection
    #
    # @return [DataMapper::Collection]
    #   +self+
    #
    # @api public
    def concat(resources)
      relate_resources(resources)
      super
    end

    ##
    # Append one or more Resources to the Collection
    #
    # This should append one or more Resources to the Collection and
    # relate each to the Collection.
    #
    # @param [Enumerable] *resources
    #   List of Resources to append
    #
    # @return [DataMapper::Collection]
    #   self
    #
    # @api public
    def push(*resources)
      relate_resources(resources)
      super
    end

    ##
    # Prepend one or more Resources to the Collection
    #
    # This should prepend one or more Resources to the Collection and
    # relate each to the Collection.
    #
    # @param [Enumerable] *resources
    #   The Resources to prepend
    #
    # @return [DataMapper::Collection]
    #   self
    #
    # @api public
    def unshift(*resources)
      relate_resources(resources)
      super
    end

    ##
    # Inserts the Resources before the Resource at the offset (which may be negative).
    #
    # @param [Integer] offset
    #   The offset to insert the Resources before
    # @param [Enumerable] *resources
    #   List of Resources to insert
    #
    # @return [DataMapper::Collection]
    #   self
    #
    # @api public
    def insert(offset, *resources)
      relate_resources(resources)
      super
    end

    ##
    # Removes and returns the last Resource in the Collection
    #
    # @return [DataMapper::Resource]
    #   the last Resource in the Collection
    #
    # @api public
    def pop
      orphan_resource(super)
    end

    # Removes and returns the first Resource in the Collection
    #
    # @return [DataMapper::Resource]
    #   the first Resource in the Collection
    #
    # @api public
    def shift
      orphan_resource(super)
    end

    ##
    # Remove Resource from the Collection
    #
    # This should remove an included Resource from the Collection and
    # orphan it from the Collection.  If the Resource is not within the
    # Collection, it should return nil.
    #
    # @param [DataMapper::Resource] resource the Resource to remove from
    #   the Collection
    #
    # @return [DataMapper::Resource]
    #   If +resource+ is within the Collection
    # @return [NilClass]
    #   If +resource+ is not within the Collection
    #
    # @api public
    def delete(resource)
      orphan_resource(super)
    end

    ##
    # Remove Resource from the Collection by offset
    #
    # This should remove the Resource from the Collection at a given
    # offset and orphan it from the Collection.  If the offset is out of
    # range return nil.
    #
    # @param [Integer] offset
    #   the offset of the Resource to remove from the Collection
    #
    # @return [DataMapper::Resource]
    #   If +offset+ is within the Collection
    # @return [NilClass]
    #   If +offset+ is not within the Collection
    #
    # @api public
    def delete_at(offset)
      orphan_resource(super)
    end

    ##
    # Deletes every Resource for which block evaluates to true.
    #
    # @yield [DataMapper::Resource] Each resource in the Collection
    #
    # @return [DataMapper::Collection] self
    #
    # @api public
    def delete_if
      super { |r| yield(r) && orphan_resource(r) }
    end

    ##
    # Deletes every Resource for which block evaluates to true.
    #
    # @yield [DataMapper::Resource] Each resource in the Collection
    #
    # @return [DataMapper::Collection]
    #   If resources were removed
    # @return [NilClass]
    #   If no resources were removed
    #
    # @api public
    def reject!
      super { |r| yield(r) && orphan_resource(r) }
    end

    ##
    # Replace the Resources within the Collection
    #
    # @param [Enumerable] other
    #   List of other Resources to replace with
    #
    # @return [DataMapper::Collection]
    #   self
    #
    # @api public
    def replace(other)
      if loaded?
        orphan_resources(self)
      end
      other = other.map { |r| r.kind_of?(Hash) ? new(r) : r }
      relate_resources(other)
      super(other)
    end

    ##
    # Removes all Resources from the Collection
    #
    # This should remove and orphan each Resource from the Collection.
    #
    # @return [DataMapper::Collection]
    #   self
    #
    # @api public
    def clear
      if loaded?
        orphan_resources(self)
      end
      super
    end

    # @api public
    # @deprecated
    def build(*args)
      warn "#{self.class}#build is deprecated, use #{self.class}#new instead"
      new(*args)
    end

    ##
    # Finds the first Resource by conditions, or initializes a new
    # Resource with the attributes if none found
    #
    # @param [Hash] conditions
    #   The conditions to be used to search
    # @param [Hash] attributes
    #   The attributes to be used to create the record of none is found.
    # @return [DataMapper::Resource]
    #   The instance found by +query+, or created with +attributes+ if none found
    #
    # @api public
    def first_or_new(conditions, attributes = {})
      first(conditions) || new(conditions.merge(attributes))
    end

    ##
    # Finds the first Resource by conditions, or creates a new
    # Resource with the attributes if none found
    #
    # @param [Hash] conditions
    #   The conditions to be used to search
    # @param [Hash] attributes
    #   The attributes to be used to create the record of none is found.
    # @return [DataMapper::Resource]
    #   The instance found by +query+, or created with +attributes+ if none found
    #
    # @api public
    def first_or_create(conditions, attributes = {})
      first(conditions) || create(conditions.merge(attributes))
    end

    ##
    # Initializes a Resource and appends it to the Collection
    #
    # @param [Hash] attributes
    #   Attributes with which to initialize the new resource.
    #
    # @return [DataMapper::Resource]
    #   a new Resource initialized with +attributes+
    #
    # @api public
    def new(attributes = {})
      resource = repository.scope { model.new(default_attributes.update(attributes)) }
      self << resource
      resource
    end

    ##
    # Creates a new Resource, saves it, and appends it to the Collection
    # if it was successfully saved.
    #
    # @param [Hash] attributes
    #   Attributes with which to create the new resource.
    #
    # @return [DataMapper::Resource]
    #   a saved Resource
    #
    # @api public
    def create(attributes = {})
      resource = repository.scope { model.create(default_attributes.update(attributes)) }
      self << resource unless resource.new_record?
      resource
    end

    ##
    # Update every Resource in the Collection
    #
    #   Person.all(:age.gte => 21).update(:allow_beer => true)
    #
    # @param [Hash] attributes attributes to update with
    # @param [Array] allowed allowed attributes to update
    #
    # @return [TrueClass, FalseClass] true if successful
    #
    # @api public
    def update(attributes = {}, *allowed)
      attributes = attributes.only(*allowed) if allowed.any?
      dirty_attributes = model.new(attributes).dirty_attributes
      dirty_attributes.empty? || all? { |r| r.update(attributes, *allowed) }
    end

    ##
    # Update every Resource in the Collection bypassing validation
    #
    #   Person.all(:age.gte => 21).update!(:allow_beer => true)
    #
    # @param [Hash] attributes attributes to update
    # @param [Array] allowed allowed attributes to update
    #
    # @return [TrueClass, FalseClass] true if successful
    #
    # @api public
    def update!(attributes = {}, *allowed)
      attributes = attributes.only(*allowed) if allowed.any?

      dirty_attributes = model.new(attributes).dirty_attributes

      if dirty_attributes.empty?
        true
      elsif dirty_attributes.only(*model.key).values.any? { |v| v.blank? }
        false
      else
        updated = repository.update(dirty_attributes, query)

        if loaded?
          each { |r| r.attributes = attributes }
          updated == size
        else
          true
        end
      end
    end

    ##
    # Remove all Resources from the repository with callbacks & validation
    #
    # This performs a deletion of each Resource in the Collection from
    # the repository and clears the Collection.
    #
    # @return [TrueClass, FalseClass] true if successful
    #
    # @api public
    def destroy
      if all? { |r| r.destroy }
        clear
        true
      else
        false
      end
    end

    ##
    # Remove all Resources from the repository bypassing validation
    #
    # This performs a deletion of each Resource in the Collection from
    # the repository and clears the Collection while skipping foreign
    # key validation.
    #
    # @return [TrueClass, FalseClass] true if successful
    #
    # @api public
    def destroy!
      destroyed = repository.delete(query)

      if loaded?
        each { |r| r.reset }
        size = self.size
        clear
        destroyed == size
      else
        true
      end
    end

    ##
    # Returns the PropertySet representing the fields in the Collection scope
    #
    # @return [DataMapper::PropertySet]
    #   The set of properties this Collection's query will retrieve
    #
    # @api semipublic
    def properties
      PropertySet.new(query.fields)
    end

    ##
    # Returns the Relationships for the Collection's Model
    #
    # @return [Hash]
    #   The model's relationships, mapping the name to the
    #   DataMapper::Associations::Relationship object
    #
    # @api semipublic
    def relationships
      model.relationships(repository.name)
    end

    ##
    # check to see if collection can respond to the method
    #
    # @param [Symbol] method
    #   method to check in the object
    # @param [TrueClass, FalseClass] include_private
    #   if set to true, collection will check private methods
    #
    # @return [TrueClass, FalseClass]
    #   true if method can be responded to
    #
    # @api public
    def respond_to?(method, include_private = false)
      super || model.respond_to?(method) || relationships.has_key?(method)
    end

    ##
    # Returns true if the other object is identical to self
    #
    # @param [DataMapper::Collection] other
    #   Another Collection object to compare with +self+
    #
    # @return [TrueClass, FalseClass]
    #   true if the objects are identical
    #
    # @api public
    def equal?(other)
      object_id == other.object_id
    end

    ##
    # Gets a Human-readable representation of this collection,
    # showing all elements contained in it
    #
    # @return [String]
    #   Human-readable representation of this collection, showing all elements
    #
    # @api public
    def inspect
      "[" << map {|r| r.inspect }.join(", ") << "]"
    end

    protected

    ##
    # Returns the Model
    #
    # @return [DataMapper::Model]
    #   the Model the Collection is associated with
    #
    # @api private
    def model
      query.model
    end

    private

    ##
    # Initializes a new DataMapper::Collection identified by the query.
    #
    # @param [DataMapper::Query] query
    #   Scope the results of the Collection
    # @param [Enumerable] resources (optional)
    #   List of resources to initialize the Collection with
    #
    # @return [DataMapper::Collection] self
    #
    # @api semipublic
    def initialize(query, resources = nil)
      assert_kind_of 'query',     query,     Query
      assert_kind_of 'resources', resources, Array if resources

      @query   = query
      @cache   = {}
      @orphans = Set.new

      super()

      if !resources.nil?
        replace(resources)
      elsif block_given?
        load_with { |c| yield(c) }
      else
        raise ArgumentError, 'must provide either a list of Resources or a block'
      end
    end

    ##
    # Copies the original Collection state
    #
    # @api private
    def initialize_copy(original)
      super
      @query   = @query.dup
      @cache   = @cache.dup
      @orphans = @orphans.dup
    end

    ##
    # Returns default values to initialize new Resources in the Collection
    #
    # @return [Hash] The default attributes for new instances in this Collection
    #
    # @api private
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
    # Relates a Resource to the Collection
    #
    # This is used by SEL related code to reload a Resource and the
    # Collection it belongs to.
    #
    # @param [DataMapper::Resource] resource
    #   The Resource to relate
    #
    # @return [DataMapper::Resource]
    #   If Resource was successfully related
    # @return [NilClass]
    #   If a nil resource was provided
    #
    # @api private
    def relate_resource(resource)
      return if resource.nil?

      resource.collection = self

      unless resource.new_record?
        @cache[resource.key] = resource
        @orphans.delete(resource)
      end

      resource
    end

    ##
    # Relate a list of Resources to the Collection
    #
    # @param [Enumerable] resources
    #   The list of Resources to relate
    #
    # @api private
    def relate_resources(resources)
      if resources.kind_of?(Enumerable)
        resources.each { |r| relate_resource(r) }
      else
        relate_resource(resources)
      end
    end

    ##
    # Orphans a Resource from the Collection
    #
    # Removes the association between the Resource and Collection so that
    # SEL related code will not load the Collection.
    #
    # @param [DataMapper::Resource] resource
    #   The Resource to orphan
    #
    # @return [DataMapper::Resource]
    #   The Resource that was orphaned
    # @return [NilClass]
    #   If a nil resource was provided
    #
    # @api private
    def orphan_resource(resource)
      return if resource.nil?

      if resource.collection.equal?(self)
        resource.collection = nil
      end

      unless resource.new_record?
        @cache.delete(resource.key)
        @orphans << resource
      end

      resource
    end

    ##
    # Orphan an list of Resources from the Collection
    #
    # @param [Enumerable] resources
    #   The list of Resources to orphan
    #
    # @api private
    def orphan_resources(resources)
      if resources.kind_of?(Enumerable)
        resources.each { |r| orphan_resource(r) }
      else
        orphan_resource(resources)
      end
    end

    # TODO: move the logic to create relative query into DataMapper::Query
    # @api private
    def scoped_query(query = nil)
      assert_kind_of 'query', query, Query, Hash if query

      # a nil query, or an empty Hash signal that we want to use the
      # same scope as is currently in effect
      if query.blank?
        return self.query
      end

      # a Query object signals that we want to use an absolute query
      if query.kind_of?(Query)
        return query
      end

      # use current query scope to start
      relative_query = query_to_hash(self.query)

      # merge in query to further scope the results
      relative_query.update(query)

      # use the repository if explicitly specified, otherwise use the current scope's repository
      repository = relative_query.delete(:repository) || self.repository

      # figure out the offset and limit relative to the current query
      if relative_query[:offset] > 0 || relative_query[:limit]
        offset, limit = get_relative_position(*relative_query.values_at(:offset, :limit))

        relative_query.update(:offset => offset)

        if limit
          relative_query.update(:limit => limit)
        end
      end

      Query.new(repository, model, relative_query)
    end

    # TODO: move the logic to create relative query into DataMapper::Query
    # @api private
    def get_relative_position(offset, limit)
      if self.query.limit.nil? && self.query.offset == 0
        # original query is unbounded, do nothing
        return offset, limit
      elsif offset == 0 && limit && self.query.limit && limit <= self.query.limit
        # new query is subset of original query, do nothing
        return offset, limit
      end

      # find the relative offset
      first_pos = self.query.offset + offset

      # find the absolute last position (if any)
      if self.query.limit
        last_pos = self.query.offset + self.query.limit
      end

      # if a limit was specified, and there is no last position, or
      # the relative limit is within range, narrow the window
      if limit && (last_pos.nil? || first_pos + limit < last_pos)
        last_pos = first_pos + limit
      end

      # the last position is below the relative offset then the
      # query cannot be satisfied. throw an exception
      if last_pos && first_pos >= last_pos
        raise 'outside range'  # TODO: raise a proper exception object
      end

      return first_pos, last_pos ? last_pos - first_pos : nil
    end

    # TODO: move this to Query#to_hash
    # @api private
    def query_to_hash(query)
      hash = {
        :reload       => query.reload?,
        :unique       => query.unique?,
        :offset       => query.offset,
        :order        => query.order,
        :add_reversed => query.add_reversed?,
        :fields       => query.fields,
      }

      hash[:limit]    = query.limit    unless query.limit    == nil
      hash[:links]    = query.links    unless query.links    == []
      hash[:includes] = query.includes unless query.includes == []

      conditions  = {}
      raw_queries = []
      bind_values = []

      query.conditions.each do |condition|
        if condition[0] == :raw
          raw_queries << condition[1]
          bind_values << condition[2]
        else
          operator, property, bind_value = condition
          conditions[Query::Operator.new(property, operator)] = bind_value
        end
      end

      if raw_queries.any?
        hash[:conditions] = [ raw_queries.join(' ') ].concat(bind_values)
      end

      hash.update(conditions)
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
      if model.respond_to?(method)
        delegate_to_model(method, *args, &block)
      elsif relationship = relationships[method] || relationships[method.to_s.singular.to_sym]
        delegate_to_relationship(relationship, *args)
      else
        super
      end
    end

    ##
    # Delegate the method to the Model
    #
    # @api private
    def delegate_to_model(method, *args, &block)
      model.__send__(:with_scope, query) do
        model.send(method, *args, &block)
      end
    end

    ##
    # Delegate the method to the Relationship
    #
    # @return [DataMapper::Collection] the associated Resources
    #
    def delegate_to_relationship(relationship, *args)
      target_class, target_key, source_key = nil, nil, nil

      if relationship.type == Associations::ManyToOne
        target_class = relationship.parent_model
        target_key   = relationship.parent_key
        source_key   = relationship.child_key
      else
        target_class = relationship.child_model
        target_key   = relationship.child_key
        source_key   = relationship.parent_key
      end

      # TODO: when self.query includes an offset/limit use it as a
      # subquery to scope the results rather than a join

      values = map { |r| source_key.get(r) }
      query  = Query.new(repository, target_class, target_key.zip(values.transpose).to_hash)

      query.update(relationship.query)

      if args.last.kind_of?(Hash)
        query.update(args.pop)
      end

      query.update(:links => [ relationship ] + self.query.links)

      target_class.all(query)
    end
  end # class Collection
end # module DataMapper
