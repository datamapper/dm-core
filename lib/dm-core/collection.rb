# TODO: if Collection is scoped by a unique property, should adding
# new Resources be denied?

# TODO: add #copy method

# TODO: move Collection#loaded_entries to LazyArray
# TODO: move Collection#partially_loaded to LazyArray

module DataMapper
  # The Collection class represents a list of resources persisted in
  # a repository and identified by a query.
  #
  # A Collection should act like an Array in every way, except that
  # it will attempt to defer loading until the results from the
  # repository are needed.
  #
  # A Collection is typically returned by the Model#all
  # method.
  class Collection < LazyArray
    extend Deprecate

    deprecate :add,   :<<
    deprecate :build, :new

    # Returns the Query the Collection is scoped with
    #
    # @return [Query]
    #   the Query the Collection is scoped with
    #
    # @api semipublic
    attr_reader :query

    # Returns the Repository
    #
    # @return [Repository]
    #   the Repository this Collection is associated with
    #
    # @api semipublic
    def repository
      query.repository
    end

    # Returns the Model
    #
    # @return [Model]
    #   the Model the Collection is associated with
    #
    # @api semipublic
    def model
      query.model
    end

    # Reloads the Collection from the repository
    #
    # If +query+ is provided, updates this Collection's query with its conditions
    #
    #   cars_from_91 = Cars.all(:year_manufactured => 1991)
    #   cars_from_91.first.year_manufactured = 2001   # note: not saved
    #   cars_from_91.reload
    #   cars_from_91.first.year                       #=> 1991
    #
    # @param [Query, Hash] query (optional)
    #   further restrict results with query
    #
    # @return [self]
    #
    # @api public
    def reload(other_query = nil)
      query = self.query
      query = other_query.nil? ? query.dup : query.merge(other_query)

      # make sure the Identity Map contains all the existing resources
      identity_map = repository.identity_map(model)

      loaded_entries.each do |resource|
        identity_map[resource.key] = resource
      end

      # sort fields based on declared order, for more consistent reload queries
      properties = self.properties
      fields     = properties & (query.fields | model_key | [ properties.discriminator ].compact)

      # replace the list of resources
      replace(all(query.update(:fields => fields, :reload => true)))
    end

    # Return the union with another collection
    #
    # @param [Collection] other
    #   the other collection
    #
    # @return [Collection]
    #   the union of the collection and other
    #
    # @api public
    def union(other)
      set_operation(:|, other)
    end

    alias | union
    alias + union

    # Return the intersection with another collection
    #
    # @param [Collection] other
    #   the other collection
    #
    # @return [Collection]
    #   the intersection of the collection and other
    #
    # @api public
    def intersection(other)
      set_operation(:&, other)
    end

    alias & intersection

    # Return the difference with another collection
    #
    # @param [Collection] other
    #   the other collection
    #
    # @return [Collection]
    #   the difference of the collection and other
    #
    # @api public
    def difference(other)
      set_operation(:-, other)
    end

    alias - difference

    # Lookup a Resource in the Collection by key
    #
    # This looksup a Resource by key, typecasting the key to the
    # proper object if necessary.
    #
    #   toyotas = Cars.all(:manufacturer => 'Toyota')
    #   toyo = Cars.first(:manufacturer => 'Toyota')
    #   toyotas.get(toyo.id) == toyo                  #=> true
    #
    # @param [Enumerable] *key
    #   keys which uniquely identify a resource in the Collection
    #
    # @return [Resource]
    #   Resource which matches the supplied key
    # @return [nil]
    #   No Resource matches the supplied key
    #
    # @api public
    def get(*key)
      assert_valid_key_size(key)

      key   = model_key.typecast(key)
      query = self.query

      @identity_map[key] || if !loaded? && (query.limit || query.offset > 0)
        # current query is exclusive, find resource within the set

        # TODO: use a subquery to retrieve the Collection and then match
        #   it up against the key.  This will require some changes to
        #   how subqueries are generated, since the key may be a
        #   composite key.  In the case of DO adapters, it means subselects
        #   like the form "(a, b) IN(SELECT a, b FROM ...)", which will
        #   require making it so the Query condition key can be a
        #   Property or an Array of Property objects

        # use the brute force approach until subquery lookups work
        lazy_load
        @identity_map[key]
      else
        # current query is all inclusive, lookup using normal approach
        first(model.key_conditions(repository, key))
      end
    end

    # Lookup a Resource in the Collection by key, raising an exception if not found
    #
    # This looksup a Resource by key, typecasting the key to the
    # proper object if necessary.
    #
    # @param [Enumerable] *key
    #   keys which uniquely identify a resource in the Collection
    #
    # @return [Resource]
    #   Resource which matches the supplied key
    # @return [nil]
    #   No Resource matches the supplied key
    #
    # @raise [ObjectNotFoundError] Resource could not be found by key
    #
    # @api public
    def get!(*key)
      get(*key) || raise(ObjectNotFoundError, "Could not find #{model.name} with key #{key.inspect}")
    end

    # Returns a new Collection optionally scoped by +query+
    #
    # This returns a new Collection scoped relative to the current
    # Collection.
    #
    #   cars_from_91 = Cars.all(:year_manufactured => 1991)
    #   toyotas_91 = cars_from_91.all(:manufacturer => 'Toyota')
    #   toyotas_91.all? { |car| car.year_manufactured == 1991 }       #=> true
    #   toyotas_91.all? { |car| car.manufacturer == 'Toyota' }        #=> true
    #
    # If +query+ is a Hash, results will be found by merging +query+ with this Collection's query.
    # If +query+ is a Query, results will be found using +query+ as an absolute query.
    #
    # @param [Hash, Query] query
    #   optional parameters to scope results with
    #
    # @return [Collection]
    #   Collection scoped by +query+
    #
    # @api public
    def all(query = nil)
      # TODO: update this not to accept a nil value, and instead either
      # accept a Hash/Query and nothing else
      if query.nil? || (query.kind_of?(Hash) && query.empty?)
        dup
      else
        # TODO: if there is no order parameter, and the Collection is not loaded
        # check to see if the query can be satisfied by the head/tail
        new_collection(scoped_query(query))
      end
    end

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
    # @return [Resource, Collection]
    #   The first resource in the entries of this collection,
    #   or a new collection whose query has been merged
    #
    # @api public
    def first(*args)
      first_arg = args.first
      last_arg  = args.last

      limit_specified = first_arg.kind_of?(Integer)
      with_query      = (last_arg.kind_of?(Hash) && !last_arg.empty?) || last_arg.kind_of?(Query)

      limit = limit_specified ? first_arg : 1
      query = with_query      ? last_arg  : {}

      query = self.query.slice(0, limit).update(query)

      # TODO: when a query provided, and there are enough elements in head to
      # satisfy the query.limit, filter the head with the query, and make
      # sure it matches the limit exactly.  if so, use that result instead
      # of calling all()
      #   - this can probably only be done if there is no :order parameter

      loaded = loaded?
      head   = self.head

      collection = if !with_query && (loaded || lazy_possible?(head, limit))
        new_collection(query, super(limit))
      else
        all(query)
      end

      return collection if limit_specified

      resource = collection.to_a.first

      if with_query || loaded
        resource
      elsif resource
        head[0] = resource
      end
    end

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
    # @return [Resource, Collection]
    #   The last resource in the entries of this collection,
    #   or a new collection whose query has been merged
    #
    # @api public
    def last(*args)
      first_arg = args.first
      last_arg  = args.last

      limit_specified = first_arg.kind_of?(Integer)
      with_query      = (last_arg.kind_of?(Hash) && !last_arg.empty?) || last_arg.kind_of?(Query)

      limit = limit_specified ? first_arg : 1
      query = with_query      ? last_arg  : {}

      query = self.query.slice(0, limit).update(query).reverse!

      # tell the Query to prepend each result from the adapter
      query.update(:add_reversed => !query.add_reversed?)

      # TODO: when a query provided, and there are enough elements in tail to
      # satisfy the query.limit, filter the tail with the query, and make
      # sure it matches the limit exactly.  if so, use that result instead
      # of calling all()

      loaded = loaded?
      tail   = self.tail

      collection = if !with_query && (loaded || lazy_possible?(tail, limit))
        new_collection(query, super(limit))
      else
        all(query)
      end

      return collection if limit_specified

      resource = collection.to_a.last

      if with_query || loaded
        resource
      elsif resource
        tail[tail.empty? ? 0 : -1] = resource
      end
    end

    # Lookup a Resource from the Collection by offset
    #
    # @param [Integer] offset
    #   offset of the Resource in the Collection
    #
    # @return [Resource]
    #   Resource which matches the supplied offset
    # @return [nil]
    #   No Resource matches the supplied offset
    #
    # @api public
    def at(offset)
      if loaded? || partially_loaded?(offset)
        super
      elsif offset >= 0
        first(:offset => offset)
      else
        last(:offset => offset.abs - 1)
      end
    end

    # Access LazyArray#slice directly
    #
    # Collection#[]= uses this to bypass Collection#slice and access
    # the resources directly so that it can orphan them properly.
    #
    # @api private
    alias superclass_slice slice
    private :superclass_slice

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
    # @return [Resource, Collection, nil]
    #   The entry which resides at that offset and limit,
    #   or a new Collection object with the set limits and offset
    # @return [nil]
    #   The offset (or starting offset) is out of range
    #
    # @raise [ArgumentError] "arguments may be 1 or 2 Integers,
    #   or 1 Range object, was: #{args.inspect}"
    #
    # @api public
    def [](*args)
      offset, limit = extract_slice_arguments(*args)

      if args.size == 1 && args.first.kind_of?(Integer)
        return at(offset)
      end

      query = sliced_query(offset, limit)

      if loaded? || partially_loaded?(offset, limit)
        new_collection(query, super)
      else
        new_collection(query)
      end
    end

    alias slice []

    # Deletes and Returns the Resources given by an offset or a Range
    #
    # @param [Integer, Array(Integer), Range] *args
    #   the offset, offset and limit, or range indicating first and last position
    #
    # @return [Resource, Collection]
    #   The entry which resides at that offset and limit, or
    #   a new Collection object with the set limits and offset
    # @return [Resource, Collection, nil]
    #   The offset is out of range
    #
    # @api public
    def slice!(*args)
      removed = super

      resources_removed(removed) unless removed.nil?

      # Workaround for Ruby <= 1.8.6
      compact! if RUBY_VERSION <= '1.8.6'

      unless removed.kind_of?(Enumerable)
        return removed
      end

      offset, limit = extract_slice_arguments(*args)

      query = sliced_query(offset, limit)

      new_collection(query, removed)
    end

    # Splice a list of Resources at a given offset or range
    #
    # When nil is provided instead of a Resource or a list of Resources
    # this will remove all of the Resources at the specified position.
    #
    # @param [Integer, Array(Integer), Range] *args
    #   The offset, offset and limit, or range indicating first and last position.
    #   The last argument may be a Resource, a list of Resources or nil.
    #
    # @return [Resource, Enumerable]
    #   the Resource or list of Resources that was spliced into the Collection
    # @return [nil]
    #   If nil was used to delete the entries
    #
    # @api public
    def []=(*args)
      orphans = Array(superclass_slice(*args[0..-2]))

      # relate new resources
      resources = resources_added(super)

      # mark resources as removed
      resources_removed(orphans - loaded_entries)

      resources
    end

    alias splice []=

    # Return a copy of the Collection sorted in reverse
    #
    # @return [Collection]
    #   Collection equal to +self+ but ordered in reverse
    #
    # @api public
    def reverse
      dup.reverse!
    end

    # Return the Collection sorted in reverse
    #
    # @return [self]
    #
    # @api public
    def reverse!
      query.reverse!

      # reverse without kicking if possible
      if loaded?
        @array.reverse!
      else
        # reverse and swap the head and tail
        @head, @tail = tail.reverse!, head.reverse!
      end

      self
    end

    # Iterate over each Resource
    #
    # @yield [Resource] Each resource in the collection
    #
    # @return [self]
    #
    # @api public
    def each
      super do |resource|
        begin
          original, resource.collection = resource.collection, self
          yield resource
        ensure
          resource.collection = original
        end
      end
    end

    # Invoke the block for each resource and replace it the return value
    #
    # @yield [Resource] Each resource in the collection
    #
    # @return [self]
    #
    # @api public
    def collect!
      super { |resource| resource_added(yield(resource_removed(resource))) }
    end

    alias map! collect!

    # Append one Resource to the Collection and relate it
    #
    # @param [Resource] resource
    #   the resource to add to this collection
    #
    # @return [self]
    #
    # @api public
    def <<(resource)
      super(resource_added(resource))
    end

    # Appends the resources to self
    #
    # @param [Enumerable] resources
    #   List of Resources to append to the collection
    #
    # @return [self]
    #
    # @api public
    def concat(resources)
      super(resources_added(resources))
    end

    # Append one or more Resources to the Collection
    #
    # This should append one or more Resources to the Collection and
    # relate each to the Collection.
    #
    # @param [Enumerable] *resources
    #   List of Resources to append
    #
    # @return [self]
    #
    # @api public
    def push(*resources)
      super(*resources_added(resources))
    end

    # Prepend one or more Resources to the Collection
    #
    # This should prepend one or more Resources to the Collection and
    # relate each to the Collection.
    #
    # @param [Enumerable] *resources
    #   The Resources to prepend
    #
    # @return [self]
    #
    # @api public
    def unshift(*resources)
      super(*resources_added(resources))
    end

    # Inserts the Resources before the Resource at the offset (which may be negative).
    #
    # @param [Integer] offset
    #   The offset to insert the Resources before
    # @param [Enumerable] *resources
    #   List of Resources to insert
    #
    # @return [self]
    #
    # @api public
    def insert(offset, *resources)
      super(offset, *resources_added(resources))
    end

    # Removes and returns the last Resource in the Collection
    #
    # @return [Resource]
    #   the last Resource in the Collection
    #
    # @api public
    def pop(*)
      if removed = super
        resources_removed(removed)
      end
    end

    # Removes and returns the first Resource in the Collection
    #
    # @return [Resource]
    #   the first Resource in the Collection
    #
    # @api public
    def shift(*)
      if removed = super
        resources_removed(removed)
      end
    end

    # Remove Resource from the Collection
    #
    # This should remove an included Resource from the Collection and
    # orphan it from the Collection.  If the Resource is not within the
    # Collection, it should return nil.
    #
    # @param [Resource] resource the Resource to remove from
    #   the Collection
    #
    # @return [Resource]
    #   If +resource+ is within the Collection
    # @return [nil]
    #   If +resource+ is not within the Collection
    #
    # @api public
    def delete(resource)
      if resource = super
        resource_removed(resource)
      end
    end

    # Remove Resource from the Collection by offset
    #
    # This should remove the Resource from the Collection at a given
    # offset and orphan it from the Collection.  If the offset is out of
    # range return nil.
    #
    # @param [Integer] offset
    #   the offset of the Resource to remove from the Collection
    #
    # @return [Resource]
    #   If +offset+ is within the Collection
    # @return [nil]
    #   If +offset+ is not within the Collection
    #
    # @api public
    def delete_at(offset)
      if resource = super
        resource_removed(resource)
      end
    end

    # Deletes every Resource for which block evaluates to true.
    #
    # @yield [Resource] Each resource in the Collection
    #
    # @return [self]
    #
    # @api public
    def delete_if
      super { |resource| yield(resource) && resource_removed(resource) }
    end

    # Deletes every Resource for which block evaluates to true
    #
    # @yield [Resource] Each resource in the Collection
    #
    # @return [Collection]
    #   If resources were removed
    # @return [nil]
    #   If no resources were removed
    #
    # @api public
    def reject!
      super { |resource| yield(resource) && resource_removed(resource) }
    end

    # Access LazyArray#replace directly
    #
    # @api private
    alias superclass_replace replace
    private :superclass_replace

    # Replace the Resources within the Collection
    #
    # @param [Enumerable] other
    #   List of other Resources to replace with
    #
    # @return [self]
    #
    # @api public
    def replace(other)
      other = resources_added(other)
      resources_removed(entries - other)
      super(other)
    end

    # (Private) Set the Collection
    #
    # @param [Array] resources
    #   resources to add to the collection
    #
    # @return [self]
    #
    # @api private
    def set(resources)
      superclass_replace(resources_added(resources))
      self
    end

    # Removes all Resources from the Collection
    #
    # This should remove and orphan each Resource from the Collection
    #
    # @return [self]
    #
    # @api public
    def clear
      if loaded?
        resources_removed(self)
      end
      super
    end

    # Finds the first Resource by conditions, or initializes a new
    # Resource with the attributes if none found
    #
    # @param [Hash] conditions
    #   The conditions to be used to search
    # @param [Hash] attributes
    #   The attributes to be used to initialize the resource with if none found
    # @return [Resource]
    #   The instance found by +query+, or created with +attributes+ if none found
    #
    # @api public
    def first_or_new(conditions = {}, attributes = {})
      first(conditions) || new(conditions.merge(attributes))
    end

    # Finds the first Resource by conditions, or creates a new
    # Resource with the attributes if none found
    #
    # @param [Hash] conditions
    #   The conditions to be used to search
    # @param [Hash] attributes
    #   The attributes to be used to create the resource with if none found
    # @return [Resource]
    #   The instance found by +query+, or created with +attributes+ if none found
    #
    # @api public
    def first_or_create(conditions = {}, attributes = {})
      first(conditions) || create(conditions.merge(attributes))
    end

    # Initializes a Resource and appends it to the Collection
    #
    # @param [Hash] attributes
    #   Attributes with which to initialize the new resource
    #
    # @return [Resource]
    #   a new Resource initialized with +attributes+
    #
    # @api public
    def new(attributes = {})
      resource = repository.scope { model.new(attributes) }
      self << resource
      resource
    end

    # Create a Resource in the Collection
    #
    # @param [Hash(Symbol => Object)] attributes
    #   attributes to set
    #
    # @return [Resource]
    #   the newly created Resource instance
    #
    # @api public
    def create(attributes = {})
      _create(true, attributes)
    end

    # Create a Resource in the Collection, bypassing hooks
    #
    # @param [Hash(Symbol => Object)] attributes
    #   attributes to set
    #
    # @return [Resource]
    #   the newly created Resource instance
    #
    # @api public
    def create!(attributes = {})
      _create(false, attributes)
    end

    # Update every Resource in the Collection
    #
    #   Person.all(:age.gte => 21).update(:allow_beer => true)
    #
    # @param [Hash] attributes
    #   attributes to update with
    #
    # @return [Boolean]
    #   true if the resources were successfully updated
    #
    # @api public
    def update(attributes = {})
      assert_update_clean_only(:update)

      dirty_attributes = model.new(attributes).dirty_attributes
      dirty_attributes.empty? || all? { |resource| resource.update(attributes) }
    end

    # Update every Resource in the Collection bypassing validation
    #
    #   Person.all(:age.gte => 21).update!(:allow_beer => true)
    #
    # @param [Hash] attributes
    #   attributes to update
    #
    # @return [Boolean]
    #   true if the resources were successfully updated
    #
    # @api public
    def update!(attributes = {})
      assert_update_clean_only(:update!)

      model = self.model

      dirty_attributes = model.new(attributes).dirty_attributes

      if dirty_attributes.empty?
        true
      elsif dirty_attributes.any? { |property, value| !property.valid?(value) }
        false
      else
        unless _update(dirty_attributes)
          return false
        end

        if loaded?
          each do |resource|
            dirty_attributes.each { |property, value| property.set!(resource, value) }
            repository.identity_map(model)[resource.key] = resource
          end
        end

        true
      end
    end

    # Save every Resource in the Collection
    #
    # @return [Boolean]
    #   true if the resources were successfully saved
    #
    # @api public
    def save
      _save(true)
    end

    # Save every Resource in the Collection bypassing validation
    #
    # @return [Boolean]
    #   true if the resources were successfully saved
    #
    # @api public
    def save!
      _save(false)
    end

    # Remove every Resource in the Collection from the repository
    #
    # This performs a deletion of each Resource in the Collection from
    # the repository and clears the Collection.
    #
    # @return [Boolean]
    #   true if the resources were successfully destroyed
    #
    # @api public
    def destroy
      if destroyed = all? { |resource| resource.destroy }
        clear
      end

      destroyed
    end

    # Remove all Resources from the repository, bypassing validation
    #
    # This performs a deletion of each Resource in the Collection from
    # the repository and clears the Collection while skipping
    # validation.
    #
    # @return [Boolean]
    #   true if the resources were successfully destroyed
    #
    # @api public
    def destroy!
      repository = self.repository
      deleted    = repository.delete(self)

      if loaded?
        unless deleted == size
          return false
        end

        each { |resource| resource.reset }
        clear
      else
        mark_loaded
      end

      true
    end

    # Check to see if collection can respond to the method
    #
    # @param [Symbol] method
    #   method to check in the object
    # @param [Boolean] include_private
    #   if set to true, collection will check private methods
    #
    # @return [Boolean]
    #   true if method can be responded to
    #
    # @api public
    def respond_to?(method, include_private = false)
      super || model.respond_to?(method) || relationships.key?(method)
    end

    # Checks if all the resources have no changes to save
    #
    # @return [Boolean]
    #   true if the resource may not be persisted
    #
    # @api public
    def clean?
      !dirty?
    end

    # Checks if any resources have unsaved changes
    #
    # @return [Boolean]
    #  true if the resources have unsaved changed
    #
    # @api public
    def dirty?
      loaded_entries.any? { |resource| resource.dirty? } || @removed.any?
    end

    # Gets a Human-readable representation of this collection,
    # showing all elements contained in it
    #
    # @return [String]
    #   Human-readable representation of this collection, showing all elements
    #
    # @api public
    def inspect
      "[#{map { |resource| resource.inspect }.join(', ')}]"
    end

    # @api semipublic
    def hash
      query.hash
    end

    protected

    # Returns the model key
    #
    # @return [PropertySet]
    #   the model key
    #
    # @api private
    def model_key
      model.key(repository_name)
    end

    # Loaded Resources in the collection
    #
    # @return [Array<Resource>]
    #   Resources in the collection
    #
    # @api private
    def loaded_entries
      (loaded? ? self : head + tail).reject { |resource| resource.destroyed? }
    end

    # Returns the PropertySet representing the fields in the Collection scope
    #
    # @return [PropertySet]
    #   The set of properties this Collection's query will retrieve
    #
    # @api private
    def properties
      model.properties(repository_name)
    end

    # Returns the Relationships for the Collection's Model
    #
    # @return [Hash]
    #   The model's relationships, mapping the name to the
    #   Associations::Relationship object
    #
    # @api private
    def relationships
      model.relationships(repository_name)
    end

    private

    # Initializes a new Collection identified by the query
    #
    # @param [Query] query
    #   Scope the results of the Collection
    # @param [Enumerable] resources (optional)
    #   List of resources to initialize the Collection with
    #
    # @return [self]
    #
    # @api private
    def initialize(query, resources = nil)
      raise "#{self.class}#new with a block is deprecated" if block_given?

      @query        = query
      @identity_map = IdentityMap.new
      @removed      = Set.new

      super()

      # TODO: change LazyArray to not use a load proc at all
      remove_instance_variable(:@load_with_proc)

      set(resources) if resources
    end

    # Copies the original Collection state
    #
    # @param [Collection] original
    #   the original collection to copy from
    #
    # @return [undefined]
    #
    # @api private
    def initialize_copy(original)
      super
      @query        = @query.dup
      @identity_map = @identity_map.dup
      @removed      = @removed.dup
    end

    # Initialize a resource from a Hash
    #
    # @param [Resource, Hash] resource
    #   resource to process
    #
    # @return [Resource]
    #   an initialized resource
    #
    # @api private
    def initialize_resource(resource)
      resource.kind_of?(Hash) ? new(resource) : resource
    end

    # Test if the collection is loaded between the offset and limit
    #
    # @param [Integer] offset
    #   the offset of the collection to test
    # @param [Integer] limit
    #   optional limit for how many entries to be loaded
    #
    # @return [Boolean]
    #   true if the collection is loaded from the offset to the limit
    #
    # @api private
    def partially_loaded?(offset, limit = 1)
      if offset >= 0
        lazy_possible?(head, offset + limit)
      else
        lazy_possible?(tail, offset.abs)
      end
    end

    # Lazy loads a Collection
    #
    # @return [self]
    #
    # @api private
    def lazy_load
      if loaded?
        return self
      end

      mark_loaded

      head  = self.head
      tail  = self.tail
      query = self.query

      resources = repository.read(query)

      # remove already known results
      resources -= head          if head.any?
      resources -= tail          if tail.any?
      resources -= @removed.to_a if @removed.any?

      query.add_reversed? ? unshift(*resources.reverse) : concat(resources)

      # TODO: DRY this up with LazyArray
      @array.unshift(*head)
      @array.concat(tail)

      @head = @tail = nil
      @reapers.each { |resource| @array.delete_if(&resource) } if @reapers
      @array.freeze if frozen?

      self
    end

    # Returns the Query Repository name
    #
    # @return [Symbol]
    #   the repository name
    #
    # @api private
    def repository_name
      repository.name
    end

    # Initializes a new Collection
    #
    # @return [Collection]
    #   A new Collection object
    #
    # @api private
    def new_collection(query, resources = nil, &block)
      if loaded?
        resources ||= filter(query)
      end

      # TOOD: figure out a way to pass not-yet-saved Resources to this newly
      # created Collection.  If the new resource matches the conditions, then
      # it should be added to the collection (keep in mind limit/offset too)

      self.class.new(query, resources, &block)
    end

    # Apply a set operation on self and another collection
    #
    # @param [Symbol] operation
    #   the set operation to apply
    # @param [Collection] other
    #   the other collection to apply the set operation on
    #
    # @return [Collection]
    #   the collection that was created for the set operation
    #
    # @api private
    def set_operation(operation, other)
      resources   = set_operation_resources(operation, other)
      other_query = Query.target_query(repository, model, other)
      new_collection(query.send(operation, other_query), resources)
    end

    # Prepopulate the set operation if the collection is loaded
    #
    # @param [Symbol] operation
    #   the set operation to apply
    # @param [Collection] other
    #   the other collection to apply the set operation on
    #
    # @return [nil]
    #   nil if the Collection is not loaded
    # @return [Array]
    #   the resources to prepopulate the set operation results with
    #
    # @api private
    def set_operation_resources(operation, other)
      entries.send(operation, other.entries) if loaded?
    end

    # Creates a resource in the collection
    #
    # @param [Boolean] safe
    #   Whether to use the safe or unsafe create
    # @param [Hash] attributes
    #   Attributes with which to create the new resource
    #
    # @return [Resource]
    #   a saved Resource
    #
    # @api private
    def _create(safe, attributes)
      resource = repository.scope { model.send(safe ? :create : :create!, default_attributes.merge(attributes)) }
      self << resource if resource.saved?
      resource
    end

    # Updates a collection
    #
    # @return [Boolean]
    #   Returns true if collection was updated
    #
    # @api private
    def _update(dirty_attributes)
      repository.update(dirty_attributes, self)
      true
    end

    # Saves a collection
    #
    # @param [Symbol] method
    #   The name of the Resource method to save the collection with
    #
    # @return [Boolean]
    #   Returns true if collection was updated
    #
    # @api private
    def _save(safe)
      loaded_entries = self.loaded_entries
      loaded_entries.each { |resource| set_default_attributes(resource) }
      @removed.clear
      loaded_entries.all? { |resource| resource.__send__(safe ? :save : :save!) }
    end

    # Returns default values to initialize new Resources in the Collection
    #
    # @return [Hash] The default attributes for new instances in this Collection
    #
    # @api private
    def default_attributes
      return @default_attributes if @default_attributes

      default_attributes = {}

      conditions = query.conditions

      if conditions.slug == :and
        model_properties = properties.dup
        model_key        = self.model_key

        if model_properties.to_set.superset?(model_key.to_set)
          model_properties -= model_key
        end

        conditions.each do |condition|
          next unless condition.slug == :eql

          subject = condition.subject
          next unless model_properties.include?(subject) || (condition.relationship? && subject.source_model == model)

          default_attributes[subject] = condition.value
        end
      end

      @default_attributes = default_attributes.freeze
    end

    # Set the default attributes for a non-frozen resource
    #
    # @param [Resource] resource
    #   the resource to set the default attributes for
    #
    # @return [undefined]
    #
    # @api private
    def set_default_attributes(resource)
      unless resource.readonly?
        resource.attributes = default_attributes
      end
    end

    # Track the added resource
    #
    # @param [Resource] resource
    #   the resource that was added
    #
    # @return [Resource]
    #   the resource that was added
    #
    # @api private
    def resource_added(resource)
      resource = initialize_resource(resource)

      if resource.saved?
        @identity_map[resource.key] = resource
        @removed.delete(resource)
      else
        set_default_attributes(resource)
      end

      resource
    end

    # Track the added resources
    #
    # @param [Array<Resource>] resources
    #   the resources that were added
    #
    # @return [Array<Resource>]
    #   the resources that were added
    #
    # @api private
    def resources_added(resources)
      if resources.kind_of?(Enumerable)
        resources.map { |resource| resource_added(resource) }
      else
        resource_added(resources)
      end
    end

    # Track the removed resource
    #
    # @param [Resource] resource
    #   the resource that was removed
    #
    # @return [Resource]
    #   the resource that was removed
    #
    # @api private
    def resource_removed(resource)
      if resource.saved?
        @identity_map.delete(resource.key)
        @removed << resource
      end

      resource
    end

    # Track the removed resources
    #
    # @param [Array<Resource>] resources
    #   the resources that were removed
    #
    # @return [Array<Resource>]
    #   the resources that were removed
    #
    # @api private
    def resources_removed(resources)
      if resources.kind_of?(Enumerable)
        resources.each { |resource| resource_removed(resource) }
      else
        resource_removed(resources)
      end
    end

    # Filter resources in the collection based on a Query
    #
    # @param [Query] query
    #   the query to match each resource in the collection
    #
    # @return [Array]
    #   the resources that match the Query
    # @return [nil]
    #   nil if no resources match the Query
    #
    # @api private
    def filter(other_query)
      query  = self.query
      fields = query.fields.to_set
      unique = other_query.unique?

      # TODO: push this into a Query#subset? method
      if other_query.links.empty?                 &&
        (unique || (!unique && !query.unique?))   &&
        !other_query.reload?                      &&
        !other_query.raw?                         &&
        other_query.fields.to_set.subset?(fields) &&
        other_query.condition_properties.subset?(fields)
      then
        other_query.filter_records(to_a.dup)
      end
    end

    # Return the absolute or relative scoped query
    #
    # @param [Query, Hash] query
    #   the query to scope the collection with
    #
    # @return [Query]
    #   the absolute or relative scoped query
    #
    # @api private
    def scoped_query(query)
      if query.kind_of?(Query)
        query.dup
      else
        self.query.relative(query)
      end
    end

    # @api private
    def sliced_query(offset, limit)
      query = self.query

      if offset >= 0
        query.slice(offset, limit)
      else
        query = query.slice((limit + offset).abs, limit).reverse!

        # tell the Query to prepend each result from the adapter
        query.update(:add_reversed => !query.add_reversed?)
      end
    end

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
    # @return [Object]
    #   the return values of the delegated methods
    #
    # @api public
    def method_missing(method, *args, &block)
      relationships = self.relationships

      if model.model_method_defined?(method)
        delegate_to_model(method, *args, &block)
      elsif relationship = relationships[method] || relationships[method.to_s.singular.to_sym]
        delegate_to_relationship(relationship, *args)
      else
        super
      end
    end

    # Delegate the method to the Model
    #
    # @param [Symbol] method
    #   the name of the method in the model to execute
    # @param [Array] *args
    #   the arguments for the method
    #
    # @return [Object]
    #   the return value of the model method
    #
    # @api private
    def delegate_to_model(method, *args, &block)
      model = self.model
      model.__send__(:with_scope, query) do
        model.send(method, *args, &block)
      end
    end

    # Delegate the method to the Relationship
    #
    # @return [Collection]
    #   the associated Resources
    #
    # @api private
    def delegate_to_relationship(relationship, query = nil)
      relationship.eager_load(self, query)
    end

    # Raises an exception if #update is performed on a dirty resource
    #
    # @raise [UpdateConflictError]
    #   raise if the resource is dirty
    #
    # @return [undefined]
    #
    # @api private
    def assert_update_clean_only(method)
      if dirty?
        raise UpdateConflictError, "#{self.class}##{method} cannot be called on a dirty collection"
      end
    end

    # Raises an exception if #get receives the wrong number of arguments
    #
    # @param [Array] key
    #   the key value
    #
    # @return [undefined]
    #
    # @raise [UpdateConflictError]
    #   raise if the resource is dirty
    #
    # @api private
    def assert_valid_key_size(key)
      expected_key_size = model_key.size
      actual_key_size   = key.size

      if actual_key_size != expected_key_size
        raise ArgumentError, "The number of arguments for the key is invalid, expected #{expected_key_size} but was #{actual_key_size}"
      end
    end
  end # class Collection
end # module DataMapper
