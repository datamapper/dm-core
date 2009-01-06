require 'set'

module DataMapper
  module Model

    ##
    # Creates a new Model class with default_storage_name +storage_name+
    #
    # If a block is passed, it will be eval'd in the context of the new Model
    #
    # @param [Proc] block
    #   a block that will be eval'd in the context of the new Model class
    #
    # @return [DataMapper::Model]
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
            #{Extlib::Inflection.classify(storage_name).inspect}
          end
        RUBY
      end

      model.instance_eval(&block) if block_given?
      model
    end

    ##
    # Extends the model with this module after DataMapper::Resource has been
    # included.
    #
    # This is a useful way to extend DataMapper::Model while
    # still retaining a self.extended method.
    #
    # @param [Module] extensions
    #   List of modules that will extend the model after it is
    #   extended by DataMapper::Model
    #
    # @return [TrueClass, FalseClass]
    #   whether or not the inclusions have been successfully appended to the list
    #
    # @api semipublic
    def self.append_extensions(*extensions)
      extra_extensions.concat extensions
      true
    end

    # TODO: document
    # @api private
    def self.extra_extensions
      @extra_extensions ||= []
    end

    # TODO: document
    # @api private
    def self.extended(model)
      model.instance_variable_set(:@storage_names, {})
      model.instance_variable_set(:@properties,    {})
      model.instance_variable_set(:@field_naming_conventions, {})
      extra_extensions.each { |extension| model.extend(extension) }
    end

    # TODO: document
    # @api private
    def inherited(target)
      target.instance_variable_set(:@storage_names,       @storage_names.dup)
      target.instance_variable_set(:@properties,          {})
      target.instance_variable_set(:@base_model,          self.base_model)
      target.instance_variable_set(:@paranoid_properties, @paranoid_properties)
      target.instance_variable_set(:@field_naming_conventions,  @field_naming_conventions.dup)

      if self.respond_to?(:validators)
        @validations.contexts.each do |context, validators|
          validators.each { |validator| target.validators.context(context) << validator }
        end
      end

      @properties.each do |repository_name,properties|
        repository(repository_name) do
          properties.each do |property|
            next if target.properties(repository_name).include?(property)
            target.property(property.name, property.type, property.options.dup)
          end
        end
      end

      if @relationships
        duped_relationships = {}
        @relationships.each do |repository_name,relationships|
          relationships.each do |name, relationship|
            dup = relationship.dup
            dup.instance_variable_set(:@child_model, target) if dup.instance_variable_get(:@child_model) == self
            dup.instance_variable_set(:@parent_model, target) if dup.instance_variable_get(:@parent_model) == self
            duped_relationships[repository_name] ||= {}
            duped_relationships[repository_name][name] = dup
          end
        end
        target.instance_variable_set(:@relationships, duped_relationships)
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
      @storage_names[repository_name] ||= repository(repository_name).adapter.resource_naming_convention.call(base_model.send(:default_storage_name))
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
    # Gets the field naming conventions for this resource in the given Repository
    #
    # @param [String, Symbol] repository_name
    #   the name of the Repository for which the field naming convention
    #   will be retrieved
    #
    # @return [#call]
    #   The naming convention for the given Repository
    #
    # @api public
    def field_naming_convention(repository_name = default_storage_name)
      @field_naming_conventions[repository_name] ||= repository(repository_name).adapter.field_naming_convention
    end

    ##
    # Defines a Property on the Resource
    #
    # @param [Symbol] name
    #   the name for which to call this property
    # @param [DataMapper::Type] type
    #   the type to define this property ass
    # @param [Hash(Symbol => String)] options
    #   a hash of available options
    #
    # @return [DataMapper::Property]
    #   the created Property
    #
    # @see DataMapper::Property
    #
    # @api public
    def property(name, type, options = {})
      property = Property.new(self, name, type, options)

      properties(repository_name)[property.name] = property
      @_valid_relations = false

      # Add property to the other mappings as well if this is for the default
      # repository.
      if repository_name == default_repository_name
        @properties.each_pair do |repository_name, properties|
          next if repository_name == default_repository_name
          properties << property unless properties.include?(property)
        end
      end

      # Add the property to the lazy_loads set for this resources repository
      # only.
      # TODO Is this right or should we add the lazy contexts to all
      # repositories?
      if property.lazy?
        context = options.fetch(:lazy, :default)
        context = :default if context == true

        Array(context).each do |item|
          properties(repository_name).lazy_context(item) << name
        end
      end

      # add the property to the child classes only if the property was
      # added after the child classes' properties have been copied from
      # the parent
      if respond_to?(:descendants)
        descendants.each do |model|
          next if model.properties(repository_name).named?(name)
          model.property(name, type, options)
        end
      end

      property
    end

    ##
    # Gets a list of all properties that have been defined on this Model in
    # the requested repository
    #
    # @param [Symbol, String] repository_name
    #   The name of the repository to use. Uses the default Repository
    #   if none is specified.
    #
    # @return [Array]
    #   A list of Properties defined on this Model in the given Repository
    #
    # @api public
    def properties(repository_name = default_repository_name)
      # We need to check whether all relations are already set up.
      # If this isn't the case, we try to reload them here
      if !@_valid_relations && respond_to?(:many_to_one_relationships)
        @_valid_relations = true
        begin
          many_to_one_relationships.each do |r|
            r.child_key
          end
        rescue NameError
          # Apparently not all relations are loaded,
          # so we will try again later on
          @_valid_relations = false
        end
      end
      @properties[repository_name] ||= repository_name == Repository.default_name ? PropertySet.new : properties(Repository.default_name).dup
    end

    ##
    # Gets the list of key fields for this Model in +repository_name+
    #
    # @param [String] repository_name
    #   The name of the Repository for which the key is to be reported
    #
    # @return [Array]
    #   The list of key fields for this Model in +repository_name+
    #
    # @api public
    def key(repository_name = default_repository_name)
      properties(repository_name).key
    end

    # TODO: document
    # @api public
    def identity_field(repository_name = default_repository_name)
      key(repository_name).detect { |p| p.serial? }
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
    # @return [DataMapper::Resource]
    #   A single model that was found
    # @return [NilClass]
    #   If no instance was found matching +key+
    #
    # @api public
    def get(*key)
      key = typecast_key(key)
      return if key.any? { |v| v.blank? }
      repository.identity_map(self)[key] || first(to_query(repository, key))
    end

    ##
    # Grab a single record just like #get, but raise an ObjectNotFoundError
    # if the record doesn't exist.
    #
    # @param [Object] *key
    #   The primary key or keys to use for lookup
    # @return [DataMapper::Resource]
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
    #   Zoo.all                         # all zoos
    #   Zoo.all(:open => true)          # all zoos that are open
    #   Zoo.all(:opened_on => (s..e))   # all zoos that opened on a date in the date-range
    #   Zoo.all(:order => [:tiger_count.desc])  # Ordered by tiger_count
    #
    # @param [Hash] query
    #   A hash describing the conditions and order for the query
    # @return [DataMapper::Collection]
    #   A set of records found matching the conditions in +query+
    # @see DataMapper::Collection
    #
    # @api public
    def all(query = {})
      Collection.new(scoped_query(query))
    end

    ##
    # Performs a query just like #all, however, only return the first
    # record found, rather than a collection
    #
    # @param [Hash] query
    #   A hash describing the conditions and order for the query
    # @return [DataMapper::Resource]
    #   The first record found by the query
    #
    # @api public
    def first(*args)
      query = args.last.respond_to?(:merge) ? args.pop : {}
      query = scoped_query(query.merge(:limit => args.first || 1))

      if args.any?
        Collection.new(query)
      else
        query.repository.read_one(query)
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
    # Create an instance of Resource with the given attributes
    #
    # @param [Hash(Symbol => Object)] attributes
    #   hash of attributes to set
    #
    # @return [DataMapper::Resource]
    #   the newly created (and saved) Resource instance
    #
    # @api public
    def create(attributes = {})
      resource = new(attributes)
      resource.save
      resource
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
    # @return [DataMapper::Collection]
    #   A Collection of the Resource instances created in the operation
    #
    # @api public
    def copy(source, destination, query = {})

      # get the list of properties that exist in the source and destination
      destination_properties = properties(destination)
      fields = query[:fields] ||= properties(source).select { |p| destination_properties.include?(p) }

      repository(destination) do
        all(query.merge(:repository => repository(source))).map do |resource|
          create(fields.map { |p| [ p.name, p.get(resource) ] }.to_hash)
        end
      end
    end

    ##
    # Loads an instance of this Model, taking into account IdentityMap lookup,
    # inheritance columns(s) and Property typecasting.
    #
    # @param [Array(Object)] values
    #   an Array of values to load as the instance's values
    #
    # @return [DataMapper::Resource]
    #   the loaded Resource instance
    #
    # @api semipublic
    def load(values, query)
      repository = query.repository
      model      = self

      if inheritance_property_index = query.inheritance_property_index
        model = values.at(inheritance_property_index) || model
      end

      resource = if key_property_indexes = query.key_property_indexes(repository)
        key_values   = values.values_at(*key_property_indexes)
        identity_map = repository.identity_map(model)

        identity_map[key_values] ||= begin
          resource = model.allocate
          resource.instance_variable_set(:@repository, repository)
          resource
        end
      else
        model.allocate
      end

      resource.instance_variable_set(:@new_record, false)

      query.fields.zip(values) do |property,value|
        next if !query.reload? && property.loaded?(resource)
        value = property.custom? ? property.type.load(value, property) : property.typecast(value)
        property.set!(resource, value)
      end

      unless key_property_indexes
        resource.freeze
      end

      resource
    end

    # TODO: document
    # @api semipublic
    def base_model
      @base_model ||= self
    end

    # TODO: document
    # @api semipublic
    def relationships(*args)
      # DO NOT REMOVE!
      # method_missing depends on these existing. Without this stub,
      # a missing module can cause misleading recursive errors.
      raise NotImplementedError.new
    end

    # TODO: document
    # @api semipublic
    def default_repository_name
      Repository.default_name
    end

    # TODO: document
    # @api private
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
    # @return [Object, DataMapper::Respository]
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
      [ repository ].to_set + @properties.keys.map { |r| DataMapper.repository(r) }
    end

    # TODO: document
    # @api private
    def eager_properties(repository_name = default_repository_name)
      properties(repository_name).defaults
    end

    # TODO: document
    # @api private
    def properties_with_subclasses(repository_name = default_repository_name)
      properties = PropertySet.new
      ([ self ].to_set + (respond_to?(:descendants) ? descendants : [])).each do |model|
        model.relationships(repository_name).each_value { |relationship| relationship.child_key }
        model.many_to_one_relationships.each { |relationship| relationship.child_key }
        model.properties(repository_name).each do |property|
          properties << property unless properties.include?(property)
        end
      end
      properties
    end

    # TODO: document
    # @api private
    def paranoid_properties
      @paranoid_properties ||= {}
      @paranoid_properties
    end

    # TODO: document
    # @api private
    def set_paranoid_property(name, &block)
      self.paranoid_properties[name] = block
    end

    # TODO: document
    # @api private
    def typecast_key(key)
      self.key(repository_name).zip(key).map { |p,v| p.typecast(v) }
    end

    # TODO: document
    # @api private
    def to_query(repository, key, query = {})
      conditions = Hash[ *self.key(repository_name).zip(key).flatten ]
      Query.new(repository, self, query.merge(conditions))
    end

    private

    # TODO: document
    # @api private
    def const_missing(name)
      if name == :DM
        warn "#{name} prefix deprecated and no longer necessary"
        self
      elsif DataMapper::Types.const_defined?(name)
        DataMapper::Types.const_get(name)
      else
        super
      end
    end

    # TODO: document
    # @api private
    def default_storage_name
      self.name
    end

    # @api private
    # TODO: move the logic to create relative query into DataMapper::Query
    def scoped_query(query = self.query)
      assert_kind_of 'query', query, Query, Hash

      return self.query if query == self.query

      query = if query.kind_of?(Hash)
        Query.new(query.delete(:repository) || self.repository, self, query)
      else
        query
      end

      if self.query
        self.query.merge(query)
      else
        merge_with_default_scope(query)
      end
    end

    # TODO: document
    # @api public
    def method_missing(method, *args, &block)
      if relationship = self.relationships(repository_name)[method]
        klass = self == relationship.child_model ? relationship.parent_model : relationship.child_model
        return DataMapper::Query::Path.new(repository, [ relationship ], klass)
      end

      if property = properties(repository_name)[method]
        return property
      end

      super
    end

    # TODO: move to dm-more/dm-transactions
    module Transaction
      #
      # Produce a new Transaction for this Resource class
      #
      # @return <DataMapper::Adapters::Transaction
      #   a new DataMapper::Adapters::Transaction with all DataMapper::Repositories
      #   of the class of this DataMapper::Resource added.
      #
      # @api public
      #
      # TODO: move to dm-more/dm-transactions
      def transaction
        DataMapper::Transaction.new(self) { |block_args| yield(*block_args) }
      end
    end # module Transaction

    include Transaction

    # TODO: move to dm-more/dm-migrations
    module Migration
      # TODO: move to dm-more/dm-migrations
      def storage_exists?(repository_name = default_repository_name)
        repository(repository_name).storage_exists?(storage_name(repository_name))
      end
    end # module Migration

    include Migration
  end # module Model
end # module DataMapper
