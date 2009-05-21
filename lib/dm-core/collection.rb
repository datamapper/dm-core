# TODO: if Collection is scoped by a unique property, should adding
# new Resources be denied?

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

    ##
    # Returns the Query the Collection is scoped with
    #
    # @return [Query] the Query the Collection is scoped with
    #
    # @api semipublic
    attr_reader :query

    ##
    # Returns the Repository
    #
    # @return [Repository]
    #   the Repository this Collection is associated with
    #
    # @api semipublic
    def repository
      query.repository
    end

    ##
    # Returns the Model
    #
    # @return [Model]
    #   the Model the Collection is associated with
    #
    # @api semipublic
    def model
      query.model
    end

    ##
    # Reloads the Collection from the repository.
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
    # @return [Collection] self
    #
    # @api public
    def reload(query = nil)
      query = query.nil? ? self.query.dup : self.query.merge(query)

      resources = if loaded?
        self
      else
        head + tail
      end

      # make sure the Identity Map contains all the existing resources
      identity_map = repository.identity_map(model)

      resources.each do |resource|
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
    # @return [Resource]
    #   Resource which matches the supplied key
    # @return [NilClass]
    #   No Resource matches the supplied key
    #
    # @api public
    def get(*key)
      key = model.typecast_key(key)
      return if key.any? { |v| v.blank? }

      if resource = @identity_map[key]
        # find cached resource
        resource
      elsif !loaded? && (query.limit || query.offset > 0)
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
    # @return [Resource]
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
    #   cars_from_91 = Cars.all(:year_manufactured => 1991)
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
    # @return [Collection]
    #   Collection scoped by +query+.
    #
    # @api public
    def all(query = nil)
      if query.nil? || (query.kind_of?(Hash) && query.empty?)
        self
      else
        new_collection(scoped_query(query))
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

      collection = if !with_query && (loaded? || lazy_possible?(head, query.limit))
        new_collection(query, super(query.limit))
      else
        all(query)
      end

      if limit
        collection
      else
        relate_resource(collection.to_a.first)
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
        relate_resource(collection.to_a.last)
      end
    end

    ##
    # Lookup a Resource from the Collection by offset
    #
    # @param [Integer] offset
    #   offset of the Resource in the Collection
    #
    # @return [Resource]
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
    # @return [Resource, Collection, NilClass]
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

      if args.size == 1 && args.first.kind_of?(Integer)
        return at(offset)
      end

      query = if offset >= 0
        self.query.slice(offset, limit)
      else
        query = self.query.slice((limit + offset).abs, limit).reverse!

        # tell the Query to prepend each result from the adapter
        query.update(:add_reversed => !query.add_reversed?)
      end

      if loaded? || (offset >= 0 ? lazy_possible?(head, offset + 1) : lazy_possible?(tail, offset.abs))
        new_collection(query, super)
      else
        new_collection(query)
      end
    end

    alias slice []

    ##
    # Deletes and Returns the Resources given by an offset or a Range
    #
    # @param [Integer, Array(Integer), Range] *args
    #   the offset, offset and limit, or range indicating first and last position
    #
    # @return [Resource, Collection]
    #   The entry which resides at that offset and limit, or
    #   a new Collection object with the set limits and offset
    # @return [Resource, Collection, NilClass]
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
        self.query.slice(offset, limit)
      else
        query = self.query.slice((limit + offset).abs, limit).reverse!

        # tell the Query to prepend each result from the adapter
        query.update(:add_reversed => !query.add_reversed?)
      end

      new_collection(query, orphaned)
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
    # @return [Resource, Enumerable]
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
    # Return a copy of the Collection sorted in reverse
    #
    # @return [Collection]
    #   Collection equal to +self+ but ordered in reverse.
    #
    # @api public
    def reverse
      dup.reverse!
    end

    ##
    # Return the Collection sorted in reverse
    #
    # @return [Collection]
    #   +self+
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

    ##
    # Invoke the block for each resource and replace it the return value
    #
    # @yield [Resource] Each resource in the collection
    #
    # @return [Collection] self
    #
    # @api public
    def collect!
      super { |r| relate_resource(yield(orphan_resource(r))) }
    end

    alias map! collect!

    ##
    # Append one Resource to the Collection and relate it
    #
    # @param [Resource] resource
    #   the resource to add to this collection
    #
    # @return [Collection] self
    #
    # @api public
    def <<(resource)
      if resource.kind_of?(Hash)
        resource = new(resource)
      end

      relate_resource(resource)
      super
    end



    ##
    # Appends the resources to self
    #
    # @param [Enumerable] resources
    #   List of Resources to append to the collection
    #
    # @return [Collection]
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
    # @return [Collection]
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
    # @return [Collection]
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
    # @return [Collection]
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
    # @return [Resource]
    #   the last Resource in the Collection
    #
    # @api public
    def pop
      orphan_resource(super)
    end

    # Removes and returns the first Resource in the Collection
    #
    # @return [Resource]
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
    # @param [Resource] resource the Resource to remove from
    #   the Collection
    #
    # @return [Resource]
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
    # @return [Resource]
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
    # @yield [Resource] Each resource in the Collection
    #
    # @return [Collection] self
    #
    # @api public
    def delete_if
      super { |r| yield(r) && orphan_resource(r) }
    end

    ##
    # Deletes every Resource for which block evaluates to true.
    #
    # @yield [Resource] Each resource in the Collection
    #
    # @return [Collection]
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
    # @return [Collection]
    #   self
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
        orphan_resources(self - other)
      end

      relate_resources(other)
      super(other)
    end

    ##
    # Removes all Resources from the Collection
    #
    # This should remove and orphan each Resource from the Collection.
    #
    # @return [Collection]
    #   self
    #
    # @api public
    def clear
      if loaded?
        orphan_resources(self)
      end
      super
    end

    ##
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

    ##
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

    ##
    # Initializes a Resource and appends it to the Collection
    #
    # @param [Hash] attributes
    #   Attributes with which to initialize the new resource.
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

    ##
    # Creates a new Resource, saves it, and appends it to the Collection
    # if it was successfully saved.
    #
    # @param [Hash] attributes
    #   Attributes with which to create the new resource.
    #
    # @return [Resource]
    #   a saved Resource
    #
    # @api public
    def create(attributes = {})
      resource = repository.scope { model.create(default_attributes.merge(attributes)) }
      self << resource if resource.saved?
      resource
    end

    ##
    # Update every Resource in the Collection
    #
    #   Person.all(:age.gte => 21).update(:allow_beer => true)
    #
    # @param [Hash] attributes attributes to update with
    #
    # @return [TrueClass, FalseClass] true if successful
    #
    # @api public
    def update(attributes = {})
      dirty_attributes = model.new(attributes).dirty_attributes
      dirty_attributes.empty? || all? { |r| r.update(attributes) }
    end

    ##
    # Update every Resource in the Collection bypassing validation
    #
    #   Person.all(:age.gte => 21).update!(:allow_beer => true)
    #
    # @param [Hash] attributes attributes to update
    #
    # @return [TrueClass, FalseClass] true if successful
    #
    # @api public
    def update!(attributes = {})
      dirty_attributes = model.new(attributes).dirty_attributes

      if dirty_attributes.empty?
        true
      elsif dirty_attributes.any? { |p, v| !p.nullable? && v.nil? }
        false
      else
        unless _update(dirty_attributes)
          return false
        end

        if loaded?
          each do |resource|
            dirty_attributes.each { |p, v| p.set!(resource, v) }
            repository.identity_map(model)[resource.key] = resource
          end
        end

        true
      end
    end

    ##
    # Save every Resource in the Collection
    #
    # @return [TrueClass, FalseClass] true if successful
    #
    # @api public
    def save
      resources = if loaded?
        entries
      else
        head + tail
      end

      # FIXME: remove this once the writer method on the child side
      # is used to store the reference to the parent.
      relate_resources(resources)

      @orphans.clear

      resources.all? { |r| r.save }
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
      if destroyed = all? { |r| r.destroy }
        clear
      end

      destroyed
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
      if query.limit || query.offset > 0
        # TODO: handle this with a subquery and handle compound keys
        key = model.key(repository.name)
        raise NotImplementedError, 'Cannot work with compound keys yet' if key.size > 1
        model.all(:repository => repository, key.first => map { |r| r.key.first }).destroy!
      else
        repository.delete(self)
      end

      if loaded?
        each { |r| r.reset }
        clear
      end

      true
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
      super || model.respond_to?(method) || relationships.key?(method)
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
      "[#{map { |r| r.inspect }.join(', ')}]"
    end

    ##
    # Returns the PropertySet representing the fields in the Collection scope
    #
    # @return [PropertySet]
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
    #   Associations::Relationship object
    #
    # @api semipublic
    def relationships
      model.relationships(repository.name)
    end

    private

    ##
    # Initializes a new Collection identified by the query.
    #
    # @param [Query] query
    #   Scope the results of the Collection
    # @param [Enumerable] resources (optional)
    #   List of resources to initialize the Collection with
    #
    # @return [Collection] self
    #
    # @api semipublic
    def initialize(query, resources = nil)
      if block_given?
        raise "#{self.class}#new with a block is deprecated"
      end

      @query        = query
      @identity_map = IdentityMap.new
      @orphans      = Set.new

      super()

      if resources
        replace(resources)
      end
    end

    ##
    # Copies the original Collection state
    #
    # @api private
    def initialize_copy(original)
      super
      @query        = @query.dup
      @identity_map = @identity_map.dup
      @orphans      = @orphans.dup
    end

    ##
    # Lazy loads a Collection
    #
    # @return [Collection]
    #   +self+
    #
    # @api semipublic
    def lazy_load
      return self if loaded?

      mark_loaded

      resources = repository.read(query)

      # remove already known results
      resources -= head          if head.any?
      resources -= tail          if tail.any?
      resources -= @orphans.to_a if @orphans.any?

      query.add_reversed? ? unshift(*resources.reverse) : concat(resources)

      # TODO: DRY this up with LazyArray
      @array.unshift(*head)
      @array.concat(tail)

      @head = @tail = nil
      @reapers.each { |r| @array.delete_if(&r) } if @reapers
      @array.freeze if frozen?

      self
    end

    ##
    # Initializes a new Collection
    #
    # @return [Collection]
    #   A new Collection object
    #
    # @api private
    def new_collection(query, resources = nil, &block)
      resources ||= filter(query) if loaded?
      self.class.new(query, resources, &block)
    end

    ##
    # Updates a collection
    #
    # @return [TrueClass,FalseClass]
    #   Returns true if collection was updated
    #
    # @api private
    def _update(dirty_attributes)
      if query.limit || query.offset > 0
        attributes = dirty_attributes.map { |p, v| [ p.name, v ] }.to_hash

        # TODO: handle this with a subquery and handle compound keys
        key = model.key(repository.name)
        raise NotImplementedError, 'Cannot work with compound keys yet' if key.size > 1
        model.all(:repository => repository, key.first => map { |r| r.key.first }).update!(attributes)
      else
        repository.update(dirty_attributes, self)
        true
      end
    end

    ##
    # Returns default values to initialize new Resources in the Collection
    #
    # @return [Hash] The default attributes for new instances in this Collection
    #
    # @api private
    def default_attributes
      @default_attributes ||=
        begin
          unless query.conditions.kind_of?(Conditions::AndOperation)
            return
          end

          default_attributes = {}

          repository_name = repository.name
          properties      = model.properties(repository_name)
          key             = model.key(repository_name)

          # if all the key properties are included in the conditions,
          # then do not allow them to be default attributes
          if query.condition_properties.to_set.superset?(key.to_set)
            properties -= key
          end

          query.conditions.operands.each do |operand|
            unless operand.kind_of?(Conditions::EqualToComparison) && properties.include?(operand.property)
              next
            end

            default_attributes[operand.property.name] = operand.value
          end

          default_attributes.freeze
        end
    end

    ##
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
    # @return [NilClass]
    #   If a nil resource was provided
    #
    # @api private
    def relate_resource(resource)
      return if resource.nil?

      resource.collection = self

      if resource.saved?
        @identity_map[resource.key] = resource
        @orphans.delete(resource)
      else
        resource.attributes = default_attributes
      end

      resource
    end

    # TODO: temporary until OneToMany::Collection#relate_resource can
    # be used by ManyToMany::Collection#relate_resource
    alias collection_relate_resource relate_resource

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
    # @param [Resource] resource
    #   The Resource to orphan
    #
    # @return [Resource]
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

      if resource.saved?
        @identity_map.delete(resource.key)
        @orphans << resource
      end

      resource
    end

    # TODO: temporary until OneToMany::Collection#relate_resource can
    # be used by ManyToMany::Collection#relate_resource
    alias collection_orphan_resource orphan_resource

    ##
    # Orphan a list of Resources from the Collection
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

    # TODO: documents
    # @api private
    def filter(query)
      fields = self.query.fields.to_set

      if query.fields.to_set.subset?(fields) &&
        query.unique? == self.query.unique?  &&
        !query.add_reversed?                 &&
        !query.reload?                       &&
        !query.raw?                          &&
        query.condition_properties.subset?(fields)
      then
        query.filter_records(to_a.dup)
      end
    end

    ##
    # Return the absolute or relative scoped query
    #
    # @param [Query, Hash]
    #
    # @return [Query]
    #   the absolute or relative scoped query
    #
    # @api private
    def scoped_query(query)
      if query.kind_of?(Query)
        query
      else
        self.query.relative(query)
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
    # @return [Collection] the associated Resources
    #
    # @api private
    def delegate_to_relationship(relationship, other_query = nil)
      # TODO: spec what should happen when none of the resources in self are saved

      query = relationship.query_for(self)
      query.update(other_query) if other_query

      model.all(query)
    end
  end # class Collection
end # module DataMapper
