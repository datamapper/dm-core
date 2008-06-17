require 'set'

module DataMapper
  module Resource
    include Assertions

    def self.new(default_name, &b)
      x = Class.new
      x.send(:include, self)
      x.instance_variable_set(:@storage_names, Hash.new { |h,k| h[k] = repository(k).adapter.resource_naming_convention.call(default_name) })
      x.instance_eval(&b)
      x
    end

    # When Resource is included in a class this method makes sure
    # it gets all the methods
    #
    # -
    # @private
    def self.included(model)
      model.extend ClassMethods
      descendants << model
    end

    # Return all classes that include the DataMapper::Resource module
    #
    # ==== Returns
    # Set:: a set containing the including classes
    #
    # ==== Example
    #
    #   Class Foo
    #     include DataMapper::Resource
    #   end
    #
    #   DataMapper.Resource.decendents[1].type == Foo
    #
    # -
    # @semipublic
    def self.descendants
      @descendants ||= Set.new
    end

    # +---------------
    # Instance methods

    attr_writer :collection

    alias model class

    # returns the value of the attribute. Do not read from instance variables directly,
    # but use this method. This method handels the lazy loading the attribute and returning
    # of defaults if nessesary.
    #
    # ==== Parameters
    # name<Symbol>:: name attribute to lookup
    #
    # ==== Returns
    # <Types>:: the value stored at that given attribute, nil if none, and default if necessary
    #
    # ==== Example
    #
    #   Class Foo
    #     include DataMapper::Resource
    #
    #     property :first_name, String
    #     property :last_name, String
    #
    #     def full_name
    #       "#{attribute_get(:first_name)} #{attribute_get(:last_name)}"
    #     end
    #
    #     # using the shorter syntax
    #     def name_for_address_book
    #       "#{last_name}, #{first_name}"
    #     end
    #   end
    #
    # -
    # @semipublic
    def attribute_get(name)
      properties[name].get(self)
    end

    # sets the value of the attribute and marks the attribute as dirty
    # if it has been changed so that it may be saved. Do not set from
    # instance variables directly, but use this method. This method
    # handels the lazy loading the property and returning of defaults
    # if nessesary.
    #
    # ==== Parameters
    # name<Symbol>:: name attribute to set
    # value<Type>:: value to store at that location
    #
    # ==== Returns
    # <Types>:: the value stored at that given attribute, nil if none, and default if necessary
    #
    # ==== Example
    #
    #   Class Foo
    #     include DataMapper::Resource
    #
    #     property :first_name, String
    #     property :last_name, String
    #
    #     def full_name(name)
    #       name = name.split(' ')
    #       attribute_set(:first_name, name[0])
    #       attribute_set(:last_name, name[1])
    #     end
    #
    #     # using the shorter syntax
    #     def name_from_address_book(name)
    #       name = name.split(', ')
    #       first_name = name[1]
    #       last_name = name[0]
    #     end
    #   end
    #
    # -
    # @semipublic
    def attribute_set(name, value)
      properties[name].set(self, value)
    end

    # Compares if its the same object or if attributes are equal
    #
    # ==== Parameters
    # other<Object>:: Object to compare to
    #
    # ==== Returns
    # <True>:: the outcome of the comparison as a boolean
    #
    # -
    # @public
    def eql?(other)
      return true if object_id == other.object_id
      return false unless other.kind_of?(model)
      return true if repository == other.repository && key == other.key

      properties.each do |property|
        return false if property.get!(self) != property.get!(other)
      end

      true
    end

    alias == eql?

    # Inspection of the class name and the attributes
    #
    # ==== Returns
    # <String>:: with the class name, attributes with their values
    #
    # ==== Example
    #
    # >> Foo.new
    # => #<Foo name=nil updated_at=nil created_at=nil id=nil>
    #
    # -
    # @public
    def inspect
      attrs = []

      properties.each do |property|
        value = if property.lazy? && !attribute_loaded?(property.name) && !new_record?
          '<not loaded>'
        else
          send(property.getter).inspect
        end

        attrs << "#{property.name}=#{value}"
      end

      "#<#{model.name} #{attrs * ' '}>"
    end

    # TODO docs
    def pretty_print(pp)
      pp.group(1, "#<#{model.name}", ">") do
        pp.breakable
        pp.seplist(attributes.to_a) do |k_v|
          pp.text k_v[0].to_s
          pp.text " = "
          pp.pp k_v[1]
        end
      end
    end

    ##
    #
    # ==== Returns
    # <Repository>:: the respository this resource belongs to in the context of a collection OR in the class's context
    #
    # @public
    def repository
      @repository || model.repository
    end

    # default id method to return the resource id when there is a
    # single key, and the model was defined with a primary key named
    # something other than id
    #
    # ==== Returns
    # <Array[Key], Key> key or keys
    #
    # --
    # @public
    def id
      key = self.key
      key.first if key.size == 1
    end

    def key
      key_properties.map do |property|
        property.get!(self)
      end
    end

    def readonly!
      @readonly = true
    end

    def readonly?
      @readonly == true
    end

    # save the instance to the data-store
    #
    # ==== Returns
    # <True, False>:: results of the save
    #
    # @see DataMapper::Repository#save
    #
    # --
    # #public
    def save(context = :default)
      # Takes a context, but does nothing with it. This is to maintain the
      # same API through out all of dm-more. dm-validations requires a
      # context to be passed

      child_associations.each { |a| a.save }

      success = if dirty? || (new_record? && key_properties.any? { |p| p.serial? })
        new_record? ? create : update
      end

      if success
        original_values.clear
      end

      parent_associations.each { |a| a.save }

      success == true
    end

    # destroy the instance, remove it from the repository
    #
    # ==== Returns
    # <True, False>:: results of the destruction
    #
    # --
    # @public
    def destroy
      return false unless repository.delete(to_query)

      @new_record = true
      repository.identity_map(model).delete(key)
      original_values.clear

      properties.each do |property|
        # We'll set the original value to nil as if we had a new record
        original_values[property.name] = nil if attribute_loaded?(property.name)
      end

      true
    end

    # Checks if the attribute has been loaded
    #
    # ==== Example
    #
    #   class Foo
    #     include DataMapper::Resource
    #     property :name, String
    #     property :description, Text, :lazy => false
    #   end
    #
    #   Foo.new.attribute_loaded?(:description) # will return false
    #
    # --
    # @public
    def attribute_loaded?(name)
      instance_variable_defined?(properties[name].instance_variable_name)
    end

    # fetches all the names of the attributes that have been loaded,
    # even if they are lazy but have been called
    #
    # ==== Returns
    # Array[<Symbol>]:: names of attributes that have been loaded
    #
    # ==== Example
    #
    #   class Foo
    #     include DataMapper::Resource
    #     property :name, String
    #     property :description, Text, :lazy => false
    #   end
    #
    #   Foo.new.loaded_attributes # returns [:name]
    #
    # --
    # @public
    def loaded_attributes
      names = []
      properties.each do |property|
        names << property.name if attribute_loaded?(property.name)
      end
      names
    end

    # set of original values of properties
    #
    # ==== Returns
    # Hash:: original values of properties
    #
    # --
    # @public
    def original_values
      @original_values ||= {}
    end

    # Hash of attributes that have been marked dirty
    #
    # ==== Returns
    # Hash:: attributes that have been marked dirty
    #
    # --
    # @private
    def dirty_attributes
      dirty_attributes = {}
      properties       = self.properties

      original_values.each do |name, old_value|
        property  = properties[name]
        new_value = property.get!(self)

        if property.custom?
          new_value = property.type.dump(new_value, property)
          old_value = property.type.dump(old_value, property)
        end

        dirty = case property.track
          when :hash then old_value != new_value.hash
          else
            old_value != new_value
        end

        if dirty
          property.hash
          dirty_attributes[property] = new_value
        end
      end

      dirty_attributes
    end

    # Checks if the class is dirty
    #
    # ==== Returns
    # True:: returns if class is dirty
    #
    # --
    # @public
    def dirty?
      dirty_attributes.any?
    end

    # Checks if the attribute is dirty
    #
    # ==== Parameters
    # name<Symbol>:: name of attribute
    #
    # ==== Returns
    # True:: returns if attribute is dirty
    #
    # --
    # @public
    def attribute_dirty?(name)
      dirty_attributes.has_key?(properties[name])
    end

    def collection
      @collection ||= if query = to_query
        Collection.new(query) { |c| c << self }
      end
    end

    # Reload association and all child association
    #
    # ==== Returns
    # self:: returns the class itself
    #
    # --
    # @public
    def reload
      reload_attributes(*loaded_attributes)
      (parent_associations + child_associations).each { |association| association.reload }
      self
    end

    # Reload specific attributes
    #
    # ==== Parameters
    # *attributes<Array[<Symbol>]>:: name of attribute
    #
    # ==== Returns
    # self:: returns the class itself
    #
    # --
    # @public
    def reload_attributes(*attributes)
      collection.reload(:fields => attributes)
      self
    end

    # Checks if the model has been saved
    #
    # ==== Returns
    # True:: status if the model is new
    #
    # --
    # @public
    def new_record?
      !defined?(@new_record) || @new_record
    end

    # all the attributes of the model
    #
    # ==== Returns
    # Hash[<Symbol>]:: All the (non)-lazy attributes
    #
    # --
    # @public
    def attributes
      pairs = {}

      properties.each do |property|
        next unless property.reader_visibility == :public
        pairs[property.name] = send(property.getter)
      end

      pairs
    end

    # Mass assign of attributes
    #
    # ==== Parameters
    # value_hash <Hash[<Symbol>]>::
    #
    # --
    # @public
    def attributes=(values_hash)
      values_hash.each_pair do |k,v|
        setter = "#{k.to_s.sub(/\?\z/, '')}="

        # use the attribute mutator if it is public to set the value
        next unless respond_to?(setter, false)
        send(setter, v)
      end
    end

    # Updates attributes and saves model
    #
    # ==== Parameters
    # attributes<Hash> Attributes to be updated
    # keys<Symbol, String, Array> keys of Hash to update (others won't be updated)
    #
    # ==== Returns
    # <TrueClass, FalseClass> if model got saved or not
    #
    #-
    # @api public
    def update_attributes(hash, *update_only)
      raise 'Update takes a hash as first parameter' unless hash.is_a?(Hash)
      loop_thru = update_only.empty? ? hash.keys : update_only
      loop_thru.each { |attr|  send("#{attr}=", hash[attr]) }
      save
    end

    # TODO: add docs
    def to_query(query = {})
      model.to_query(repository, key, query) unless new_record?
    end

    protected

    def properties
      model.properties(repository.name)
    end

    def key_properties
      model.key(repository.name)
    end

    def relationships
      model.relationships(repository.name)
    end

    private

    def initialize(attributes = {}) # :nodoc:
      assert_valid_model
      self.attributes = attributes
    end

    def assert_valid_model # :nodoc:
      properties = self.properties

      if properties.empty? && relationships.empty?
        raise IncompleteResourceError, "#{model.name} must have at least one property or relationship to be initialized."
      end

      if properties.key.empty?
        raise IncompleteResourceError, "#{model.name} must have a key."
      end
    end

    def create
      # set defaults for new resource
      properties.each do |property|
        next if attribute_loaded?(property.name)
        property.set(self, property.default_for(self))
      end

      return false unless repository.create([ self ]) == 1

      @repository = repository
      @new_record = false

      repository.identity_map(model).set(key, self)

      true
    end

    def update
      dirty_attributes = self.dirty_attributes
      return true if dirty_attributes.empty?
      repository.update(dirty_attributes, to_query) == 1
    end

    # TODO document
    # @semipublic
    def attribute_get!(name)
      properties[name].get!(self)
    end

    # TODO document
    # @semipublic
    def attribute_set!(name, value)
      properties[name].set!(self, value)
    end

    def lazy_load(name)
      reload_attributes(*properties.lazy_load_context(name))
    end

    def child_associations
      @child_associations ||= []
    end

    def parent_associations
      @parent_associations ||= []
    end

    # TODO: move to dm-more/dm-transactions
    module Transaction
      # Produce a new Transaction for the class of this Resource
      #
      # ==== Returns
      # <DataMapper::Adapters::Transaction>::
      #   a new DataMapper::Adapters::Transaction with all DataMapper::Repositories
      #   of the class of this DataMapper::Resource added.
      #-
      # @api public
      #
      # TODO: move to dm-more/dm-transactions
      def transaction(&block)
        model.transaction(&block)
      end

      module ClassMethods
        #
        # Produce a new Transaction for this Resource class
        #
        # @return <DataMapper::Adapters::Transaction
        #   a new DataMapper::Adapters::Transaction with all DataMapper::Repositories
        #   of the class of this DataMapper::Resource added.
        #-
        # @api public
        #
        # TODO: move to dm-more/dm-transactions
        def transaction(&block)
          DataMapper::Transaction.new(self, &block)
        end
      end
    end

    include Transaction

    module ClassMethods
      include Transaction::ClassMethods

      def self.extended(model)
        model.instance_variable_set(:@storage_names, Hash.new { |h,k| h[k] = repository(k).adapter.resource_naming_convention.call(model.instance_eval do default_storage_name end) })
        model.instance_variable_set(:@properties,    Hash.new { |h,k| h[k] = k == Repository.default_name ? PropertySet.new : h[Repository.default_name].dup })
      end

      def inherited(target)
        target.instance_variable_set(:@storage_names, @storage_names.dup)
        target.instance_variable_set(:@properties, Hash.new { |h,k| h[k] = k == Repository.default_name ? self.properties(Repository.default_name).dup(target) : h[Repository.default_name].dup })

        if @relationships
          duped_relationships = {}; @relationships.each_pair{ |repos, rels| duped_relationships[repos] = rels.dup}
          target.instance_variable_set(:@relationships, duped_relationships)
        end
      end

      ##
      # Get the repository with a given name, or the default one for the current
      # context, or the default one for this class.
      #
      # @param name<Symbol>   the name of the repository wanted
      # @param block<Block>   block to execute with the fetched repository as parameter
      #
      # @return <Object, DataMapper::Respository> whatever the block returns,
      #   if given a block, otherwise the requested repository.
      #-
      # @api public
      def repository(name = nil, &block)
        #
        # There has been a couple of different strategies here, but me (zond) and dkubb are at least
        # united in the concept of explicitness over implicitness. That is - the explicit wish of the
        # caller (+name+) should be given more priority than the implicit wish of the caller (Repository.context.last).
        #
        DataMapper.repository(*Array(name || (Repository.context.last ? nil : default_repository_name)), &block)
      end

      ##
      # the name of the storage recepticle for this resource.  IE. table name, for database stores
      #
      # @return <String> the storage name (IE table name, for database stores) associated with this resource in the given repository
      def storage_name(repository_name = default_repository_name)
        @storage_names[repository_name]
      end

      ##
      # the names of the storage recepticles for this resource across all repositories
      #
      # @return <Hash(Symbol => String)> All available names of storage recepticles
      def storage_names
        @storage_names
      end

      ##
      # defines a property on the resource
      #
      # @param <Symbol> name the name for which to call this property
      # @param <Type> type the type to define this property ass
      # @param <Hash(Symbol => String)> options a hash of available options
      # @see DataMapper::Property
      def property(name, type, options = {})
        property = Property.new(self, name, type, options)

        create_property_getter(property)
        create_property_setter(property)

        @properties[repository.name] << property

        # Add property to the other mappings as well if this is for the default
        # repository.
        if repository.name == default_repository_name
          @properties.each_pair do |repository_name, properties|
            next if repository_name == default_repository_name
            properties << property
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
            @properties[repository.name].lazy_context(item) << name
          end
        end

        property
      end

      # TODO: make this a Set?
      def repositories
        [ repository ] + @properties.keys.collect { |repository_name| DataMapper.repository(repository_name) }
      end

      def properties(repository_name = default_repository_name)
        @properties[repository_name]
      end

      def properties_with_subclasses(repository_name = default_repository_name)
        #return properties if we're not interested in sti
       if @properties[repository_name].inheritance_property.nil?
         @properties[repository_name]
       else
          props = @properties[repository_name].dup
          self.child_classes.each do |subclass|
            subclass.properties(repository_name).each do |subprop|
              props << subprop if not props.any? { |prop| prop.name == subprop.name }
            end
          end
          props
        end
      end

      def key(repository_name = default_repository_name)
        @properties[repository_name].key
      end

      alias default_order key

      def inheritance_property(repository_name = default_repository_name)
        @properties[repository_name].inheritance_property
      end

      def get(*key)
        repository.identity_map(self).get(key) || first(to_query(repository, key))
      end

      def get!(*key)
        get(*key) || raise(ObjectNotFoundError, "Could not find #{self.name} with key #{key.inspect}")
      end

      def all(query = {})
        query = scoped_query(query)
        query.repository.read_many(query)
      end

      def first(*args)
        query = args.last.respond_to?(:merge) ? args.pop : {}
        query = scoped_query(query.merge(:limit => args.first || 1))

        if args.any?
          query.repository.read_many(query)
        else
          query.repository.read_one(query)
        end
      end

      def [](*key)
        warn("#{name}[] is deprecated. Use #{name}.get! instead.")
        get!(*key)
      end

      def first_or_create(query, attributes = {})
        first(query) || begin
          resource = allocate
          query = query.dup

          properties(repository.name).key.each do |property|
            if value = query.delete(property.name)
              resource.send("#{property.name}=", value)
            end
          end

          resource.attributes = query.merge(attributes)
          resource.save
          resource
        end
      end

      ##
      # Create an instance of Resource with the given attributes
      #
      # @param <Hash(Symbol => Object)> attributes hash of attributes to set
      def create(attributes = {})
        resource = new(attributes)
        resource.save
        resource
      end

      ##
      # Dangerous version of #create.  Raises if there is a failure
      #
      # @see DataMapper::Resource#create
      # @param <Hash(Symbol => Object)> attributes hash of attributes to set
      # @raise <PersistenceError> The resource could not be saved
      def create!(attributes = {})
        resource = create(attributes)
        raise PersistenceError, "Resource not saved: :new_record => #{resource.new_record?}, :dirty_attributes => #{resource.dirty_attributes.inspect}" if resource.new_record?
        resource
      end

      # TODO SPEC
      def copy(source, destination, query = {})
        repository(destination) do
          repository(source).read_many(query).each do |resource|
            self.create(resource)
          end
        end
      end

      # @private
      # TODO: spec this
      def load(values, query)
        repository = query.repository
        model      = self

        if inheritance_property_index = query.inheritance_property_index(repository)
          model = values.at(inheritance_property_index) || model
        end

        if key_property_indexes = query.key_property_indexes(repository)
          key_values   = values.values_at(*key_property_indexes)
          identity_map = repository.identity_map(model)

          if resource = identity_map.get(key_values)
            return resource unless query.reload?
          else
            resource = model.allocate
            resource.instance_variable_set(:@repository, repository)
            identity_map.set(key_values, resource)
          end
        else
          resource = model.allocate
          resource.readonly!
        end

        resource.instance_variable_set(:@new_record, false)

        query.fields.zip(values) do |property,value|
          value = property.custom? ? property.type.load(value, property) : property.typecast(value)
          property.set!(resource, value)

          if track = property.track
            case track
              when :hash
                resource.original_values[property.name] = value.dup.hash unless resource.original_values.has_key?(property.name) rescue value.hash
              when :load
                 resource.original_values[property.name] = value unless resource.original_values.has_key?(property.name)
            end
          end
        end

        resource
      end

      # TODO: spec this
      def to_query(repository, key, query = {})
        conditions = Hash[ *self.key(repository.name).zip(key).flatten ]
        Query.new(repository, self, query.merge(conditions))
      end

      private

      def default_storage_name
        self.name
      end

      def default_repository_name
        Repository.default_name
      end

      def scoped_query(query = self.query)
        assert_kind_of 'query', query, Query, Hash

        return self.query if query == self.query

        query = if query.kind_of?(Hash)
          Query.new(query.has_key?(:repository) ? query.delete(:repository) : self.repository, self, query)
        else
          query
        end

        self.query ? self.query.merge(query) : query
      end

      # defines the getter for the property
      def create_property_getter(property)
        class_eval <<-EOS, __FILE__, __LINE__
          #{property.reader_visibility}
          def #{property.getter}
            attribute_get(#{property.name.inspect})
          end
        EOS

        if property.primitive == TrueClass && !property.model.instance_methods.include?(property.name.to_s)
          class_eval <<-EOS, __FILE__, __LINE__
            #{property.reader_visibility}
            alias #{property.name} #{property.getter}
          EOS
        end
      end

      # defines the setter for the property
      def create_property_setter(property)
        unless instance_methods.include?(property.name.to_s + '=')
          class_eval <<-EOS, __FILE__, __LINE__
            #{property.writer_visibility}
            def #{property.name}=(value)
              attribute_set(#{property.name.inspect}, value)
            end
          EOS
        end
      end

      def method_missing(method, *args, &block)
        if relationship = relationships(repository.name)[method]
           clazz = if self == relationship.child_model
             relationship.parent_model
           else
             relationship.child_model
           end
           return DataMapper::Query::Path.new(repository, [relationship],clazz)
        end

        if property = properties(repository.name)[method]
          return property
        end
        super
      end

      # TODO: move to dm-more/dm-migrations
      module Migration
        # TODO: move to dm-more/dm-migrations
        def storage_exists?(repository_name = default_repository_name)
          repository(repository_name).storage_exists?(storage_name(repository_name))
        end
      end # module Migration

      include Migration
    end # module ClassMethods
  end # module Resource
end # module DataMapper
