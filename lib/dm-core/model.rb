# TODO: add Model#create!, Model#update, Model#update!, Model#destroy and Model#destroy!

module DataMapper
  module Model
    extend Chainable

    ##
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
        warn "Passing in +storage_name+ to #{name}.new is deprecated"
        model.class_eval <<-RUBY, __FILE__, __LINE__ + 1
          def self.default_storage_name
            #{Extlib::Inflection.classify(storage_name).inspect}.freeze
          end
        RUBY
      end

      model.instance_eval(&block) if block
      model
    end

    ##
    # Return all classes that extend the Model module
    #
    #   Class Foo
    #     include DataMapper::Resource
    #   end
    #
    #   DataMapper::Model.descendants.to_a.first   #=> Foo
    #
    # @return [Set]
    #   Set containing the including classes
    #
    # @api private
    def self.descendants
      @descendants ||= Set.new
    end

    ##
    # Appends a module for inclusion into the model class after Resource.
    #
    # This is a useful way to extend Resource while still retaining a
    # self.included method.
    #
    # @param [Module] inclusions
    #   the module that is to be appended to the module after Resource
    #
    # @return [TrueClass, FalseClass]
    #   true if the inclusions have been successfully appended to the list
    #
    # @api semipublic
    def self.append_inclusions(*inclusions)
      extra_inclusions.concat inclusions
      true
    end

    ##
    # The current registered extra inclusions
    #
    # @return [Set]
    #
    # @api private
    def self.extra_inclusions
      @extra_inclusions ||= []
    end

    ##
    # Extends the model with this module after Resource has been included.
    #
    # This is a useful way to extend Model while still retaining a self.extended method.
    #
    # @param [Module] extensions
    #   List of modules that will extend the model after it is extended by Model
    #
    # @return [TrueClass, FalseClass]
    #   whether or not the inclusions have been successfully appended to the list
    #
    # @api semipublic
    def self.append_extensions(*extensions)
      extra_extensions.concat extensions
      true
    end

    ##
    # The current registered extra extensions
    #
    # @return [Set]
    #
    # @api private
    def self.extra_extensions
      @extra_extensions ||= []
    end

    # TODO: document
    # @api private
    def self.extended(model)
      return if Model.descendants.include?(model)

      unless model.ancestors.include?(Resource)
        model.send(:include, Resource)
      end

      Model.descendants << model

      model.instance_variable_set(:@valid,         false)
      model.instance_variable_set(:@storage_names, {})

      extra_extensions.each { |mod| model.extend(mod)         }
      extra_inclusions.each { |mod| model.send(:include, mod) }
    end

    chainable do
      # TODO: document
      # @api private
      def inherited(target)
        Model.descendants << target

        target.instance_variable_set(:@valid,         false)
        target.instance_variable_set(:@storage_names, @storage_names.dup)
        target.instance_variable_set(:@base_model,    base_model)

        # TODO: move this into dm-validations
        if respond_to?(:validators)
          validators.contexts.each do |context, validators|
            target.validators.context(context).concat(validators)
          end
        end
      end
    end

    ##
    # Gets the name of the storage receptacle for this resource in the given
    # Repository (ie., table name, for database stores).
    #
    # @return [String]
    #   the storage name (ie., table name, for database stores) associated with
    #   this resource in the given repository
    #
    # @api public
    def storage_name(repository_name = default_repository_name)
      @storage_names[repository_name] ||= repository(repository_name).adapter.resource_naming_convention.call(base_model.send(:default_storage_name)).freeze
    end

    ##
    # the names of the storage receptacles for this resource across all repositories
    #
    # @return [Hash(Symbol => String)]
    #   All available names of storage recepticles
    #
    # @api public
    def storage_names
      @storage_names
    end

    ##
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
    # @return [Resource,NilClass]
    #   A single model that was found
    #   If no instance was found matching +key+
    #
    # @api public
    def get(*key)
      repository = self.repository
      key        = typecast_key(key)

      repository.identity_map(self)[key] || first(key_conditions(repository, key))
    end

    ##
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

    ##
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
      if query.nil? || (query.kind_of?(Hash) && query.empty?)
        # TODO: after adding Enumerable methods to Model, try to return self here
        new_collection(self.query)
      else
        new_collection(scoped_query(query))
      end
    end

    ##
    # Performs a query just like #all, however, only return the first
    # record found, rather than a collection
    #
    # @param [Hash] query
    #   A hash describing the conditions and order for the query
    # @return [Resource]
    #   The first record found by the query
    #
    # @api public
    def first(*args)
      query = scoped_query(args.last.respond_to?(:merge) ? args.pop : {})

      if args.any?
        new_collection(query).first(*args)
      else
        query.repository.read(query.update(:limit => 1)).first
      end
    end

    # TODO: add #last

    ##
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

    ##
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

    ##
    # Initializes an instance of Resource with the given attributes
    #
    # @param [Hash(Symbol => Object)] attributes
    #   hash of attributes to set
    #
    # @return [Resource]
    #   the newly initialized Resource instance
    #
    # @api public
    def new(attributes = {}, &block)
      assert_valid

      model = if discriminator = properties(repository_name).discriminator
        attributes[discriminator.name]
      end

      model ||= self

      resource = model.allocate
      resource.send(:initialize, attributes, &block)
      resource
    end

    ##
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

    ##
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

    ##
    # Copy a set of records from one repository to another.
    #
    # @param [String] source
    #   The name of the Repository the resources should be copied _from_
    # @param [String] destination
    #   The name of the Repository the resources should be copied _to_
    # @param [Hash] query
    #   The conditions with which to find the records to copy. These
    #   conditions are merged with Model.query
    #
    # @return [Collection]
    #   A Collection of the Resource instances created in the operation
    #
    # @api public
    def copy(source, destination, query = {})

      # get the list of properties that exist in the source and destination
      destination_properties = properties(destination)
      fields = query[:fields] ||= properties(source).select { |property| destination_properties.include?(property) }

      repository(destination) do
        all(query.merge(:repository => source)).map do |resource|
          create(fields.map { |property| [ property.name, property.get(resource) ] }.to_hash)
        end
      end
    end

    ##
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
      repository    = query.repository
      fields        = query.fields
      discriminator = properties(repository.name).discriminator
      no_reload     = !query.reload?

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

            model = discriminator && record[discriminator] || self

            resource = if (key_values = record.values_at(*key)).all?
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
            model = record.model

            resource = if (key_values = record.key).all?
              identity_map = repository.identity_map(model)
              identity_map[key_values]
            end

            resource ||= model.allocate

            fields.each do |property|
              next if no_reload && property.loaded?(resource)

              property.set!(resource, property.get!(record))
            end
        end

        resource.instance_variable_set(:@repository, repository)
        resource.instance_variable_set(:@saved,      true)

        if identity_map
          # defer setting the IdentityMap so second level caches can
          # record the state of the resource after loaded
          identity_map[key_values] = resource
        else
          resource.freeze
        end

        resource
      end
    end

    # TODO: document
    # @api semipublic
    def base_model
      @base_model ||= self
    end

    # TODO: document
    # @api semipublic
    def default_repository_name
      Repository.default_name
    end

    # TODO: document
    # @api semipublic
    def default_order(repository_name = default_repository_name)
      @default_order ||= {}
      @default_order[repository_name] ||= key(repository_name).map { |property| Query::Direction.new(property) }
    end

    ##
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
    def repository(name = nil)
      #
      # There has been a couple of different strategies here, but me (zond) and dkubb are at least
      # united in the concept of explicitness over implicitness. That is - the explicit wish of the
      # caller (+name+) should be given more priority than the implicit wish of the caller (Repository.context.last).
      #
      if block_given?
        DataMapper.repository(name || repository_name) { |*block_args| yield(*block_args) }
      else
        DataMapper.repository(name || repository_name)
      end
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
      Repository.context.any? ? Repository.context.last.name : default_repository_name
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

    # TODO: document
    # @api private
    def resource_methods
      resource_methods = Set.new

      ancestors.each do |mod|
        next unless mod <= DataMapper::Resource
        resource_methods.merge(mod.instance_methods(false).map { |method| method.to_s })
      end

      resource_methods
    end

    # TODO: document
    # @api private
    def resource_method_defined?(method)
      resource_methods.include?(method)
    end

    private

    # TODO: document
    # @api private
    def _create(safe, attributes)
      resource = new(attributes)
      resource.send(safe ? :save : :save!)
      resource
    end

    # TODO: document
    # @api private
    def const_missing(name)
      if name == :DM
        warn "#{name} prefix deprecated and no longer necessary"
        self
      elsif name == :Resource
        Resource
      elsif Types.const_defined?(name)
        Types.const_get(name)
      else
        super
      end
    end

    # TODO: document
    # @api private
    def default_storage_name
      self.name
    end

    ##
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
        query
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

        if self.query.repository == repository
          self.query.merge(query)
        else
          Query.new(repository, self, self.query.merge(query).options)
        end
      end
    end

    # @api private
    def assert_valid # :nodoc:
      return if @valid

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
          relationship.child_key if relationship.kind_of?(Associations::ManyToOne::Relationship)
          relationship.through   if relationship.respond_to?(:through)
        end
      end

      @valid = true
    end
  end # module Model
end # module DataMapper
