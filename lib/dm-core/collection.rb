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
    def reload(query = nil)
      query = query.nil? ? self.query.dup : self.query.merge(query)

      # make sure the Identity Map contains all the existing resources
      identity_map = repository.identity_map(model)

      loaded_entries.each do |resource|
        identity_map[resource.key] = resource
      end

      properties = model.properties(repository.name)
      fields     = properties.key | query.fields

      if discriminator = properties.discriminator
        fields |= [ discriminator ]
      end

      # sort fields based on declared order, for more consistent reload queries
      fields = properties & fields

      # replace the list of resources
      replace(all(query.update(:fields => fields, :reload => true)))
    end

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
      key = model.key(repository.name).typecast(key)

      resource = @identity_map[key] || if !loaded? && (query.limit || query.offset > 0)
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

      return if resource.nil?

      orphan_resource(resource)
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
      last_arg = args.last

      limit      = args.first if args.first.kind_of?(Integer)
      with_query = last_arg.respond_to?(:merge) && !last_arg.blank?

      query = with_query ? last_arg : {}
      query = self.query.slice(0, limit || 1).update(query)

      # TODO: when a query provided, and there are enough elements in head to
      # satisfy the query.limit, filter the head with the query, and make
      # sure it matches the limit exactly.  if so, use that result instead
      # of calling all()
      #   - this can probably only be done if there is no :order parameter

      collection = if !with_query && (loaded? || lazy_possible?(head, query.limit))
        new_collection(query, super(query.limit))
      else
        all(query)
      end

      if limit
        collection
      else
        collection.to_a.first
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
      last_arg = args.last

      limit      = args.first if args.first.kind_of?(Integer)
      with_query = last_arg.respond_to?(:merge) && !last_arg.blank?

      query = with_query ? last_arg : {}
      query = self.query.slice(0, limit || 1).update(query).reverse!

      # tell the Query to prepend each result from the adapter
      query.update(:add_reversed => !query.add_reversed?)

      # TODO: when a query provided, and there are enough elements in tail to
      # satisfy the query.limit, filter the tail with the query, and make
      # sure it matches the limit exactly.  if so, use that result instead
      # of calling all()

      collection = if !with_query && (loaded? || lazy_possible?(tail, query.limit))
        new_collection(query, super(query.limit))
      else
        all(query)
      end

      if limit
        collection
      else
        collection.to_a.last
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
        return unless resource = super
        orphan_resource(resource)
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

      # ensure remaining orphans are still related
      (orphans & loaded_entries).each { |resource| relate_resource(resource) }

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
      if resource.kind_of?(Hash)
        resource = new(resource)
      end

      resource_added(resource)
      super
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
      resources_added(resources)
      super
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
      resources_added(resources)
      super
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
      resources_added(resources)
      super
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
      resources_added(resources)
      super
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

    # Replace the Resources within the Collection
    #
    # @param [Enumerable] other
    #   List of other Resources to replace with
    #
    # @return [self]
    #
    # @api public
    def replace(other)
      other = other.map do |resource|
        if resource.kind_of?(Hash)
          new(resource)
        else
          resource
        end
      end

      if loaded?
        resources_removed(self - other)
      end

      super(resources_added(other))
    end

    # Access Collection#replace directly
    #
    # @api private
    alias collection_replace replace
    private :collection_replace

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

      dirty_attributes = model.new(attributes).dirty_attributes

      if dirty_attributes.empty?
        true
      elsif dirty_attributes.any? { |property, value| !property.nullable? && value.nil? }
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
      if query.limit || query.offset > 0 || query.links.any?
        key        = model.key(repository.name)
        conditions = Query.target_conditions(self, key, key)

        unless model.all(:repository => repository, :conditions => conditions).destroy!
          return false
        end
      else
        repository.delete(self)
        mark_loaded
      end

      if loaded?
        each { |resource| resource.reset }
        clear
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
    #  true if a resource may be persisted
    #
    # @api public
    def dirty?
      loaded_entries.any? { |resource| resource.dirty? }
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

    # Returns the PropertySet representing the fields in the Collection scope
    #
    # @return [PropertySet]
    #   The set of properties this Collection's query will retrieve
    #
    # @api semipublic
    def properties
      PropertySet.new(query.fields)
    end

    # Returns the Relationships for the Collection's Model
    #
    # @return [Hash]
    #   The model's relationships, mapping the name to the
    #   Associations::Relationship object
    #
    # @api semipublic
    def relationships
      model.relationships(repository.name)
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

      if resources
        replace(resources)
      end
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

    # Loaded Resources in the collection
    #
    # @return [Array<Resource>]
    #   Resources in the collection
    #
    # @api private
    def loaded_entries
      loaded? ? self : head + tail
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
      if query.limit || query.offset > 0 || query.links.any?
        attributes = dirty_attributes.map { |property, value| [ property.name, value ] }.to_hash

        key        = model.key(repository.name)
        conditions = Query.target_conditions(self, key, key)

        unless model.all(:repository => repository, :conditions => conditions).update!(attributes)
          return false
        end
      else
        repository.update(dirty_attributes, self)
      end

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
      loaded_entries.each { |resource| set_default_attributes(resource) }
      @removed.clear
      loaded_entries.all? { |resource| resource.send(safe ? :save : :save!) }
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

      if conditions.kind_of?(Query::Conditions::AndOperation)
        repository_name = repository.name
        relationships   = self.relationships.values
        properties      = model.properties(repository_name)
        key             = model.key(repository_name)

        # if all the key properties are included in the conditions,
        # then do not allow them to be default attributes
        if query.condition_properties.to_set.superset?(key.to_set)
          properties -= key
        end

        conditions.each do |condition|
          if condition.kind_of?(Query::Conditions::EqualToComparison) &&
            (properties.include?(condition.subject) || (condition.relationship? && condition.subject.source_model == model))
            default_attributes[condition.subject] = condition.value
          end
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
      unless resource.frozen?
        resource.attributes = default_attributes
      end
    end

    # Relates a Resource to the Collection
    #
    # This is used by SEL related code to reload a Resource and the
    # Collection it belongs to.
    #
    # @param [Resource] resource
    #   The Resource to relate
    #
    # @return [Resource]
    #   If Resource was successfully related
    # @return [nil]
    #   If a nil resource was provided
    #
    # @api private
    def relate_resource(resource)
      unless resource.frozen?
        resource.collection = self
      end

      resource
    end

    # Orphans a Resource from the Collection
    #
    # Removes the association between the Resource and Collection so that
    # SEL related code will not load the Collection.
    #
    # @param [Resource] resource
    #   The Resource to orphan
    #
    # @return [Resource]
    #   The Resource that was orphaned
    # @return [nil]
    #   If a nil resource was provided
    #
    # @api private
    def orphan_resource(resource)
      if resource.collection.equal?(self) && !resource.frozen?
        resource.collection = nil
      end

      resource
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
      if resource.saved?
        @identity_map[resource.key] = resource
        @removed.delete(resource)
      else
        set_default_attributes(resource)
      end

      relate_resource(resource)
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
        resources.each { |resource| resource_added(resource) }
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

      orphan_resource(resource)
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
    def filter(query)
      fields = self.query.fields.to_set

      if query.links.empty?                                        &&
        (query.unique? || (!query.unique? && !self.query.unique?)) &&
        !query.reload?                                             &&
        !query.raw?                                                &&
        query.fields.to_set.subset?(fields)                        &&
        query.condition_properties.subset?(fields)
      then
        query.filter_records(to_a.dup)
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
        raise UpdateConflictError, "##{method} cannot be called on a dirty collection"
      end
    end
  end # class Collection
end # module DataMapper
