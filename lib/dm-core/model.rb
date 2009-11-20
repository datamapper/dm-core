# TODO: add Model#create!, Model#update, Model#update!, Model#destroy and Model#destroy!

module DataMapper
  module Model
    extend Chainable

    # Creates a new Model class with default_storage_name +storage_name+
    #
    # If a block is passed, it will be eval'd in the context of the new Model
    #
    # @param [Proc] block
    #   a block that will be eval'd in the context of the new Model class
    #
    # @return [Model]
    #   the newly created Model class
    #
    # @api semipublic
    def self.new(storage_name = nil, &block)
      model = Class.new

      model.class_eval <<-RUBY, __FILE__, __LINE__ + 1
        include DataMapper::Resource

        def self.name
          to_s
        end
      RUBY

      if storage_name
        warn "Passing in +storage_name+ to #{name}.new is deprecated (#{caller[0]})"
        model.class_eval <<-RUBY, __FILE__, __LINE__ + 1
          def self.default_storage_name
            #{Extlib::Inflection.classify(storage_name).inspect}.freeze
          end
        RUBY
      end

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
    attr_reader :descendants

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
    def self.extended(model)
      descendants = self.descendants

      descendants << model

      model.instance_variable_set(:@valid,         false)
      model.instance_variable_set(:@base_model,    model)
      model.instance_variable_set(:@storage_names, {})
      model.instance_variable_set(:@default_order, {})
      model.instance_variable_set(:@descendants,   descendants.class.new(model, descendants))

      extra_extensions.each { |mod| model.extend(mod)         }
      extra_inclusions.each { |mod| model.send(:include, mod) }
    end

    # @api private
    chainable do
      def inherited(model)
        descendants = self.descendants

        descendants << model

        model.instance_variable_set(:@valid,         false)
        model.instance_variable_set(:@base_model,    base_model)
        model.instance_variable_set(:@storage_names, @storage_names.dup)
        model.instance_variable_set(:@default_order, @default_order.dup)
        model.instance_variable_set(:@descendants,   descendants.class.new(model, descendants))

        # TODO: move this into dm-validations
        if respond_to?(:validators)
          validators.contexts.each do |context, validators|
            model.validators.context(context).concat(validators)
          end
        end
      end
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
    #   All available names of storage recepticles
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

      repository.identity_map(self)[key] || first(key_conditions(repository, key))
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

    alias slice []

    def at(*args)
      all.at(*args)
    end

    def reverse
      all.reverse
    end

    # TODO: spec this
    def entries
      all.entries
    end

    alias to_a entries

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
    def all(query = nil)
      # TODO: update this not to accept a nil value, and instead either
      # accept a Hash/Query and nothing else
      if query.nil? || (query.kind_of?(Hash) && query.empty?)
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

    # Initializes an instance of Resource with the given attributes
    #
    # @param [Hash(Symbol => Object)] attributes
    #   hash of attributes to set
    #
    # @return [Resource]
    #   the newly initialized Resource instance
    #
    # @api public
    chainable do
      def new(*args, &block)
        assert_valid
        super
      end
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
      _create(true, attributes)
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
      _create(false, attributes)
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
          query[:fields].each { |property| property.set(new_resource, property.get(resource)) }
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

      field_map = fields.map { |property| [ property, property.field ] }.to_hash

      records.map do |record|
        identity_map = nil
        key_values   = nil
        resource     = nil

        case record
          when Hash
            # remap fields to use the Property object
            record = record.dup
            field_map.each { |property, field| record[property] = record.delete(field) if record.key?(field) }

            model     = discriminator && record[discriminator] || self
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
              if property.custom?
                value = property.type.load(value, property)
              end

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
        resource.instance_variable_set(:@_saved,      true)

        if identity_map
          # defer setting the IdentityMap so second level caches can
          # record the state of the resource after loaded
          identity_map[key_values] = resource
        else
          resource.instance_variable_set(:@_readonly, true)
        end

        resource
      end
    end

    # @api semipublic
    attr_reader :base_model

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

    # @api private
    def model_method_defined?(method)
      model_methods.include?(method.to_s)
    end

    # @api private
    def resource_method_defined?(method)
      resource_methods.include?(method.to_s)
    end

    private

    # @api private
    def _create(safe, attributes)
      resource = new(attributes)
      resource.__send__(safe ? :save : :save!)
      resource
    end

    # @api private
    def const_missing(name)
      if name == :DM
        warn "#{name} prefix deprecated and no longer necessary (#{caller[0]})"
        self
      elsif name == :Resource
        Resource
      elsif Types.const_defined?(name)
        Types.const_get(name)
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
          Query.new(repository, self, query.options)
        end
      end
    end

    # @api private
    def assert_valid # :nodoc:
      return if @valid
      @valid = true

      name            = self.name
      repository_name = self.repository_name

      if properties(repository_name).empty? &&
        !relationships(repository_name).any? { |(relationship_name, relationship)| relationship.kind_of?(Associations::ManyToOne::Relationship) }
        raise IncompleteModelError, "#{name} must have at least one property or many to one relationship to be valid"
      end

      if key(repository_name).empty?
        raise IncompleteModelError, "#{name} must have a key to be valid"
      end

      # initialize join models and target keys
      @relationships.each_value do |relationships|
        relationships.each_value do |relationship|
          relationship.child_key
          relationship.through if relationship.respond_to?(:through)
          relationship.via     if relationship.respond_to?(:via)
        end
      end
    end

    # @api private
    def model_methods
      @model_methods ||= ancestor_instance_methods { |mod| mod.meta_class }
    end

    # @api private
    def resource_methods
      @resource_methods ||= ancestor_instance_methods { |mod| mod }
    end

    # @api private
    def ancestor_instance_methods
      methods = Set.new

      ancestors.each do |mod|
        next unless mod <= DataMapper::Resource
        methods.merge(yield(mod).instance_methods(false).map { |method| method.to_s })
      end

      methods
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
  end # module Model
end # module DataMapper
