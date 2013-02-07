module DataMapper
  module Model
    include Enumerable

    WRITER_METHOD_REGEXP   = /=\z/.freeze
    INVALID_WRITER_METHODS = %w[ == != === []= taguri= attributes= collection= persistence_state= raise_on_save_failure= ].to_set.freeze

    # Creates a new Model class with its constant already set
    #
    # If a block is passed, it will be eval'd in the context of the new Model
    #
    # @param [#to_s] name
    #   the name of the new model
    # @param [Object] namespace
    #   the namespace that will hold the new model
    # @param [Proc] block
    #   a block that will be eval'd in the context of the new Model class
    #
    # @return [Model]
    #   the newly created Model class
    #
    # @api private
    def self.new(name = nil, namespace = Object, &block)
      model = name ? namespace.const_set(name, Class.new) : Class.new

      model.class_eval <<-RUBY, __FILE__, __LINE__ + 1
        include DataMapper::Resource
      RUBY

      model.instance_eval(&block) if block
      model
    end

    # Return all models that extend the Model module
    #
    #   class Foo
    #     include DataMapper::Resource
    #   end
    #
    #   DataMapper::Model.descendants.first   #=> Foo
    #
    # @return [DescendantSet]
    #   Set containing the descendant models
    #
    # @api semipublic
    def self.descendants
      @descendants ||= DescendantSet.new
    end

    # Return all models that inherit from a Model
    #
    #   class Foo
    #     include DataMapper::Resource
    #   end
    #
    #   class Bar < Foo
    #   end
    #
    #   Foo.descendants.first   #=> Bar
    #
    # @return [Set]
    #   Set containing the descendant classes
    #
    # @api semipublic
    def descendants
      @descendants ||= DescendantSet.new
    end

    # Return if Resource#save should raise an exception on save failures (globally)
    #
    # This is false by default.
    #
    #   DataMapper::Model.raise_on_save_failure  # => false
    #
    # @return [Boolean]
    #   true if a failure in Resource#save should raise an exception
    #
    # @api public
    def self.raise_on_save_failure
      if defined?(@raise_on_save_failure)
        @raise_on_save_failure
      else
        false
      end
    end

    # Specify if Resource#save should raise an exception on save failures (globally)
    #
    # @param [Boolean]
    #   a boolean that if true will cause Resource#save to raise an exception
    #
    # @return [Boolean]
    #   true if a failure in Resource#save should raise an exception
    #
    # @api public
    def self.raise_on_save_failure=(raise_on_save_failure)
      @raise_on_save_failure = raise_on_save_failure
    end

    # Return if Resource#save should raise an exception on save failures (per-model)
    #
    # This delegates to DataMapper::Model.raise_on_save_failure by default.
    #
    #   User.raise_on_save_failure  # => false
    #
    # @return [Boolean]
    #   true if a failure in Resource#save should raise an exception
    #
    # @api public
    def raise_on_save_failure
      if defined?(@raise_on_save_failure)
        @raise_on_save_failure
      else
        DataMapper::Model.raise_on_save_failure
      end
    end

    # Specify if Resource#save should raise an exception on save failures (per-model)
    #
    # @param [Boolean]
    #   a boolean that if true will cause Resource#save to raise an exception
    #
    # @return [Boolean]
    #   true if a failure in Resource#save should raise an exception
    #
    # @api public
    def raise_on_save_failure=(raise_on_save_failure)
      @raise_on_save_failure = raise_on_save_failure
    end

    # Finish model setup and verify it is valid
    #
    # @return [undefined]
    #
    # @api public
    def finalize
      finalize_relationships
      finalize_allowed_writer_methods
      assert_valid_name
      assert_valid_properties
      assert_valid_key
    end

    # Appends a module for inclusion into the model class after Resource.
    #
    # This is a useful way to extend Resource while still retaining a
    # self.included method.
    #
    # @param [Module] inclusions
    #   the module that is to be appended to the module after Resource
    #
    # @return [Boolean]
    #   true if the inclusions have been successfully appended to the list
    #
    # @api semipublic
    def self.append_inclusions(*inclusions)
      extra_inclusions.concat inclusions

      # Add the inclusion to existing descendants
      descendants.each do |model|
        inclusions.each { |inclusion| model.send :include, inclusion }
      end

      true
    end

    # The current registered extra inclusions
    #
    # @return [Set]
    #
    # @api private
    def self.extra_inclusions
      @extra_inclusions ||= []
    end

    # Extends the model with this module after Resource has been included.
    #
    # This is a useful way to extend Model while still retaining a self.extended method.
    #
    # @param [Module] extensions
    #   List of modules that will extend the model after it is extended by Model
    #
    # @return [Boolean]
    #   whether or not the inclusions have been successfully appended to the list
    #
    # @api semipublic
    def self.append_extensions(*extensions)
      extra_extensions.concat extensions

      # Add the extension to existing descendants
      descendants.each do |model|
        extensions.each { |extension| model.extend(extension) }
      end

      true
    end

    # The current registered extra extensions
    #
    # @return [Set]
    #
    # @api private
    def self.extra_extensions
      @extra_extensions ||= []
    end

    # @api private
    def self.extended(descendant)
      descendants << descendant

      descendant.instance_variable_set(:@valid,         false)
      descendant.instance_variable_set(:@base_model,    descendant)
      descendant.instance_variable_set(:@storage_names, {})
      descendant.instance_variable_set(:@default_order, {})

      descendant.extend(Chainable)

      extra_extensions.each { |mod| descendant.extend(mod)         }
      extra_inclusions.each { |mod| descendant.send(:include, mod) }
    end

    # @api private
    def inherited(descendant)
      descendants << descendant

      descendant.instance_variable_set(:@valid,         false)
      descendant.instance_variable_set(:@base_model,    base_model)
      descendant.instance_variable_set(:@storage_names, @storage_names.dup)
      descendant.instance_variable_set(:@default_order, @default_order.dup)
    end

    # Gets the name of the storage receptacle for this resource in the given
    # Repository (ie., table name, for database stores).
    #
    # @return [String]
    #   the storage name (ie., table name, for database stores) associated with
    #   this resource in the given repository
    #
    # @api public
    def storage_name(repository_name = default_repository_name)
      storage_names[repository_name] ||= repository(repository_name).adapter.resource_naming_convention.call(default_storage_name).freeze
    end

    # the names of the storage receptacles for this resource across all repositories
    #
    # @return [Hash(Symbol => String)]
    #   All available names of storage receptacles
    #
    # @api public
    def storage_names
      @storage_names
    end

    # Grab a single record by its key. Supports natural and composite key
    # lookups as well.
    #
    #   Zoo.get(1)                # get the zoo with primary key of 1.
    #   Zoo.get!(1)               # Or get! if you want an ObjectNotFoundError on failure
    #   Zoo.get('DFW')            # wow, support for natural primary keys
    #   Zoo.get('Metro', 'DFW')   # more wow, composite key look-up
    #
    # @param [Object] *key
    #   The primary key or keys to use for lookup
    #
    # @return [Resource, nil]
    #   A single model that was found
    #   If no instance was found matching +key+
    #
    # @api public
    def get(*key)
      assert_valid_key_size(key)

      repository = self.repository
      key        = self.key(repository.name).typecast(key)

      repository.identity_map(self)[key] || first(key_conditions(repository, key).update(:order => nil))
    end

    # Grab a single record just like #get, but raise an ObjectNotFoundError
    # if the record doesn't exist.
    #
    # @param [Object] *key
    #   The primary key or keys to use for lookup
    # @return [Resource]
    #   A single model that was found
    # @raise [ObjectNotFoundError]
    #   The record was not found
    #
    # @api public
    def get!(*key)
      get(*key) || raise(ObjectNotFoundError, "Could not find #{self.name} with key #{key.inspect}")
    end

    def [](*args)
      all[*args]
    end

    alias_method :slice, :[]

    def at(*args)
      all.at(*args)
    end

    def fetch(*args, &block)
      all.fetch(*args, &block)
    end

    def values_at(*args)
      all.values_at(*args)
    end

    def reverse
      all.reverse
    end

    def each(&block)
      return to_enum unless block_given?
      all.each(&block)
      self
    end

    # Find a set of records matching an optional set of conditions. Additionally,
    # specify the order that the records are return.
    #
    #   Zoo.all                                   # all zoos
    #   Zoo.all(:open => true)                    # all zoos that are open
    #   Zoo.all(:opened_on => start..end)         # all zoos that opened on a date in the date-range
    #   Zoo.all(:order => [ :tiger_count.desc ])  # Ordered by tiger_count
    #
    # @param [Hash] query
    #   A hash describing the conditions and order for the query
    # @return [Collection]
    #   A set of records found matching the conditions in +query+
    # @see Collection
    #
    # @api public
    def all(query = Undefined)
      if query.equal?(Undefined) || (query.kind_of?(Hash) && query.empty?)
        # TODO: after adding Enumerable methods to Model, try to return self here
        new_collection(self.query.dup)
      else
        new_collection(scoped_query(query))
      end
    end

    # Return the first Resource or the first N Resources for the Model with an optional query
    #
    # When there are no arguments, return the first Resource in the
    # Model.  When the first argument is an Integer, return a
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

      if limit_specified
        all(query)
      else
        query.repository.read(query).first
      end
    end

    # Return the last Resource or the last N Resources for the Model with an optional query
    #
    # When there are no arguments, return the last Resource for the
    # Model.  When the first argument is an Integer, return a
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

      if limit_specified
        all(query)
      else
        query.repository.read(query).last
      end
    end

    # Finds the first Resource by conditions, or initializes a new
    # Resource with the attributes if none found
    #
    # @param [Hash] conditions
    #   The conditions to be used to search
    # @param [Hash] attributes
    #   The attributes to be used to create the record of none is found.
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
    #   The attributes to be used to create the record of none is found.
    # @return [Resource]
    #   The instance found by +query+, or created with +attributes+ if none found
    #
    # @api public
    def first_or_create(conditions = {}, attributes = {})
      first(conditions) || create(conditions.merge(attributes))
    end

    # Create a Resource
    #
    # @param [Hash(Symbol => Object)] attributes
    #   attributes to set
    #
    # @return [Resource]
    #   the newly created Resource instance
    #
    # @api public
    def create(attributes = {})
      _create(attributes)
    end

    # Create a Resource, bypassing hooks
    #
    # @param [Hash(Symbol => Object)] attributes
    #   attributes to set
    #
    # @return [Resource]
    #   the newly created Resource instance
    #
    # @api public
    def create!(attributes = {})
      _create(attributes, false)
    end

    # Update every Resource
    #
    #   Person.update(:allow_beer => true)
    #
    # @param [Hash] attributes
    #   attributes to update with
    #
    # @return [Boolean]
    #   true if the resources were successfully updated
    #
    # @api public
    def update(attributes)
      all.update(attributes)
    end

    # Update every Resource, bypassing validations
    #
    #   Person.update!(:allow_beer => true)
    #
    # @param [Hash] attributes
    #   attributes to update with
    #
    # @return [Boolean]
    #   true if the resources were successfully updated
    #
    # @api public
    def update!(attributes)
      all.update!(attributes)
    end

    # Remove all Resources from the repository
    #
    # @return [Boolean]
    #   true if the resources were successfully destroyed
    #
    # @api public
    def destroy
      all.destroy
    end

    # Remove all Resources from the repository, bypassing validation
    #
    # @return [Boolean]
    #   true if the resources were successfully destroyed
    #
    # @api public
    def destroy!
      all.destroy!
    end

    # Copy a set of records from one repository to another.
    #
    # @param [String] source_repository_name
    #   The name of the Repository the resources should be copied _from_
    # @param [String] target_repository_name
    #   The name of the Repository the resources should be copied _to_
    # @param [Hash] query
    #   The conditions with which to find the records to copy. These
    #   conditions are merged with Model.query
    #
    # @return [Collection]
    #   A Collection of the Resource instances created in the operation
    #
    # @api public
    def copy(source_repository_name, target_repository_name, query = {})
      target_properties = properties(target_repository_name)

      query[:fields] ||= properties(source_repository_name).select do |property|
        target_properties.include?(property)
      end

      repository(target_repository_name) do |repository|
        resources = []

        all(query.merge(:repository => source_repository_name)).each do |resource|
          new_resource = new
          query[:fields].each { |property| new_resource.__send__("#{property.name}=", property.get(resource)) }
          resources << new_resource if new_resource.save
        end

        all(Query.target_query(repository, self, resources))
      end
    end

    # Loads an instance of this Model, taking into account IdentityMap lookup,
    # inheritance columns(s) and Property typecasting.
    #
    # @param [Enumerable(Object)] records
    #   an Array of Resource or Hashes to load a Resource with
    #
    # @return [Resource]
    #   the loaded Resource instance
    #
    # @api semipublic
    def load(records, query)
      repository      = query.repository
      repository_name = repository.name
      fields          = query.fields
      discriminator   = properties(repository_name).discriminator
      no_reload       = !query.reload?

      field_map = Hash[ fields.map { |property| [ property, property.field ] } ]

      records.map do |record|
        identity_map = nil
        key_values   = nil
        resource     = nil

        case record
          when Hash
            # remap fields to use the Property object
            record = record.dup
            field_map.each { |property, field| record[property] = record.delete(field) if record.key?(field) }

            model     = discriminator && discriminator.load(record[discriminator]) || self
            model_key = model.key(repository_name)

            resource = if model_key.valid?(key_values = record.values_at(*model_key))
              identity_map = repository.identity_map(model)
              identity_map[key_values]
            end

            resource ||= model.allocate

            fields.each do |property|
              next if no_reload && property.loaded?(resource)

              value = record[property]

              # TODO: typecasting should happen inside the Adapter
              # and all values should come back as expected objects
              value = property.load(value)

              property.set!(resource, value)
            end

          when Resource
            model     = record.model
            model_key = model.key(repository_name)

            resource = if model_key.valid?(key_values = record.key)
              identity_map = repository.identity_map(model)
              identity_map[key_values]
            end

            resource ||= model.allocate

            fields.each do |property|
              next if no_reload && property.loaded?(resource)

              property.set!(resource, property.get!(record))
            end
        end

        resource.instance_variable_set(:@_repository, repository)

        if identity_map
          resource.persistence_state = Resource::PersistenceState::Clean.new(resource) unless resource.persistence_state?

          # defer setting the IdentityMap so second level caches can
          # record the state of the resource after loaded
          identity_map[key_values] = resource
        else
          resource.persistence_state = Resource::PersistenceState::Immutable.new(resource)
        end

        resource
      end
    end

    # @api semipublic
    attr_reader :base_model

    # The list of writer methods that can be mass-assigned to in #attributes=
    #
    # @return [Set]
    #
    # @api private
    attr_reader :allowed_writer_methods

    # @api semipublic
    def default_repository_name
      Repository.default_name
    end

    # @api semipublic
    def default_order(repository_name = default_repository_name)
      @default_order[repository_name] ||= key(repository_name).map { |property| Query::Direction.new(property) }.freeze
    end

    # Get the repository with a given name, or the default one for the current
    # context, or the default one for this class.
    #
    # @param [Symbol] name
    #   the name of the repository wanted
    # @param [Block] block
    #   block to execute with the fetched repository as parameter
    #
    # @return [Object, Respository]
    #   whatever the block returns, if given a block,
    #   otherwise the requested repository.
    #
    # @api private
    def repository(name = nil, &block)
      #
      # There has been a couple of different strategies here, but me (zond) and dkubb are at least
      # united in the concept of explicitness over implicitness. That is - the explicit wish of the
      # caller (+name+) should be given more priority than the implicit wish of the caller (Repository.context.last).
      #

      DataMapper.repository(name || repository_name, &block)
    end

    # Get the current +repository_name+ for this Model.
    #
    # If there are any Repository contexts, the name of the last one will
    # be returned, else the +default_repository_name+ of this model will be
    #
    # @return [String]
    #   the current repository name to use for this Model
    #
    # @api private
    def repository_name
      context = Repository.context
      context.any? ? context.last.name : default_repository_name
    end

    # Gets the current Set of repositories for which
    # this Model has been defined (beyond default)
    #
    # @return [Set]
    #   The Set of repositories for which this Model
    #   has been defined (beyond default)
    #
    # @api private
    def repositories
      [ repository ].to_set + @properties.keys.map { |repository_name| DataMapper.repository(repository_name) }
    end

    private

    # @api private
    def _create(attributes, execute_hooks = true)
      resource = new(attributes)
      resource.__send__(execute_hooks ? :save : :save!)
      resource
    end

    # @api private
    def const_missing(name)
      if name == :DM
        raise "#{name} prefix deprecated and no longer necessary (#{caller.first})"
      elsif name == :Resource
        Resource
      else
        super
      end
    end

    # @api private
    def default_storage_name
      base_model.name
    end

    # Initializes a new Collection
    #
    # @return [Collection]
    #   A new Collection object
    #
    # @api private
    def new_collection(query, resources = nil, &block)
      Collection.new(query, resources, &block)
    end

    # @api private
    # TODO: move the logic to create relative query into Query
    def scoped_query(query)
      if query.kind_of?(Query)
        query.dup
      else
        repository = if query.key?(:repository)
          query      = query.dup
          repository = query.delete(:repository)

          if repository.kind_of?(Symbol)
            DataMapper.repository(repository)
          else
            repository
          end
        else
          self.repository
        end

        query = self.query.merge(query)

        if self.query.repository == repository
          query
        else
          repository.new_query(self, query.options)
        end
      end
    end

    # Initialize all foreign key properties established by relationships
    #
    # @return [undefined]
    #
    # @api private
    def finalize_relationships
      relationships(repository_name).each { |relationship| relationship.finalize }
    end

    # Initialize the list of allowed writer methods
    #
    # @return [undefined]
    #
    # @api private
    def finalize_allowed_writer_methods
      @allowed_writer_methods  = public_instance_methods.map { |method| method.to_s }.grep(WRITER_METHOD_REGEXP).to_set
      @allowed_writer_methods -= INVALID_WRITER_METHODS
      @allowed_writer_methods.freeze
    end

    # @api private
    # TODO: Remove this once appropriate warnings can be added.
    def assert_valid(force = false) # :nodoc:
      return if @valid && !force
      @valid = true
      finalize
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
      expected_key_size = self.key(repository_name).size
      actual_key_size   = key.size

      if actual_key_size != expected_key_size
        raise ArgumentError, "The number of arguments for the key is invalid, expected #{expected_key_size} but was #{actual_key_size}"
      end
    end

    # Test if the model name is valid
    #
    # @return [undefined]
    #
    # @api private
    def assert_valid_name
      if name.to_s.strip.empty?
        raise IncompleteModelError, "#{inspect} must have a name"
      end
    end

    # Test if the model has properties
    #
    # A model may also be valid if it has at least one m:1 relationships which
    # will add inferred foreign key properties.
    #
    # @return [undefined]
    #
    # @raise [IncompleteModelError]
    #   raised if the model has no properties
    #
    # @api private
    def assert_valid_properties
      repository_name = self.repository_name
      if properties(repository_name).empty? &&
        !relationships(repository_name).any? { |relationship| relationship.kind_of?(Associations::ManyToOne::Relationship) }
        raise IncompleteModelError, "#{name} must have at least one property or many to one relationship to be valid"
      end
    end

    # Test if the model has a valid key
    #
    # @return [undefined]
    #
    # @raise [IncompleteModelError]
    #   raised if the model does not have a valid key
    #
    # @api private
    def assert_valid_key
      if key(repository_name).empty?
        raise IncompleteModelError, "#{name} must have a key to be valid"
      end
    end

  end # module Model
end # module DataMapper
