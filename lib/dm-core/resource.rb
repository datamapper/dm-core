module DataMapper
  module Resource
    include Extlib::Assertions
    extend Chainable
    extend Deprecate

    deprecate :new_record?, :new?

    # @deprecated
    def self.append_inclusions(*inclusions)
      warn "DataMapper::Resource.append_inclusions is deprecated, use DataMapper::Model.append_inclusions instead (#{caller[0]})"
      Model.append_inclusions(*inclusions)
    end

    # @deprecated
    def self.extra_inclusions
      warn "DataMapper::Resource.extra_inclusions is deprecated, use DataMapper::Model.extra_inclusions instead (#{caller[0]})"
      Model.extra_inclusions
    end

    # @deprecated
    def self.descendants
      warn "DataMapper::Resource.descendants is deprecated, use DataMapper::Model.descendants instead (#{caller[0]})"
      Model.descendants
    end

    # Deprecated API for updating attributes and saving Resource
    #
    # @see #update
    #
    # @deprecated
    def update_attributes(attributes = {}, *allowed)
      assert_update_clean_only(:update_attributes)

      warn "#{model}#update_attributes is deprecated, use #{model}#update instead (#{caller[0]})"

      if allowed.any?
        warn "specifying allowed in #{model}#update_attributes is deprecated, " \
          "use Hash#only to filter the attributes in the caller (#{caller[0]})"
        attributes = attributes.only(*allowed)
      end

      update(attributes)
    end

    # Makes sure a class gets all the methods when it includes Resource
    #
    # @api private
    def self.included(model)
      model.extend Model
    end

    # Collection this resource associated with.
    # Used by SEL.
    #
    # @api private
    attr_writer :collection

    # TODO: document
    # @api public
    alias_method :model, :class

    # Repository this resource belongs to in the context of this collection
    # or of the resource's class.
    #
    # @return [Repository]
    #   the respository this resource belongs to, in the context of
    #   a collection OR in the instance's Model's context
    #
    # @api semipublic
    def repository
      # only set @repository explicitly when persisted
      defined?(@repository) ? @repository : model.repository
    end

    # Retrieve the key(s) for this resource.
    #
    # This always returns the persisted key value,
    # even if the key is changed and not yet persisted.
    # This is done so all relations still work.
    #
    # @return [Array(Key)]
    #   the key(s) identifying this resource
    #
    # @api public
    def key
      return @key if defined?(@key)

      key = model.key(repository_name).map do |property|
        original_attributes[property] || (property.loaded?(self) ? property.get!(self) : nil)
      end

      return unless key.all?

      # memoize the key if the Resource is not frozen
      @key = key unless frozen?

      key
    end

    # Checks if this Resource instance is new
    #
    # @return [Boolean]
    #   true if the resource is new and not saved
    #
    # @api public
    def new?
      !saved?
    end

    # Checks if this Resource instance is saved
    #
    # @return [Boolean]
    #   true if the resource has been saved
    #
    # @api public
    def saved?
      @saved == true
    end

    # Checks if this Resource instance is destroyed
    #
    # @return [Boolean]
    #   true if the resource has been destroyed
    #
    # @api public
    def destroyed?
      @destroyed == true
    end

    # Checks if the resource has no changes to save
    #
    # @return [Boolean]
    #   true if the resource may not be persisted
    #
    # @api public
    def clean?
      !dirty?
    end

    # Checks if the resource has unsaved changes
    #
    # @return [Boolean]
    #  true if resource may be persisted
    #
    # @api public
    def dirty?
      if original_attributes.any?
        true
      elsif new?
        model.serial || properties.any? { |property| property.default? }
      else
        false
      end
    end

    # Returns the value of the attribute.
    #
    # Do not read from instance variables directly, but use this method.
    # This method handles lazy loading the attribute and returning of
    # defaults if nessesary.
    #
    # @example
    #   class Foo
    #     include DataMapper::Resource
    #
    #     property :first_name, String
    #     property :last_name,  String
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
    # @param [Symbol] name
    #   name of attribute to retrieve
    #
    # @return [Object]
    #   the value stored at that given attribute
    #   (nil if none, and default if necessary)
    #
    # @api public
    def attribute_get(name)
      properties[name].get(self)
    end

    alias [] attribute_get

    # Sets the value of the attribute and marks the attribute as dirty
    # if it has been changed so that it may be saved. Do not set from
    # instance variables directly, but use this method. This method
    # handles the lazy loading the property and returning of defaults
    # if nessesary.
    #
    # @example
    #   class Foo
    #     include DataMapper::Resource
    #
    #     property :first_name, String
    #     property :last_name,  String
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
    # @param [Symbol] name
    #   name of attribute to set
    # @param [Object] value
    #   value to store
    #
    # @return [Object]
    #   the value stored at that given attribute, nil if none,
    #   and default if necessary
    #
    # @api public
    def attribute_set(name, value)
      properties[name].set(self, value)
    end

    alias []= attribute_set

    # Gets all the attributes of the Resource instance
    #
    # @param [Symbol] key_on
    #   Use this attribute of the Property as keys.
    #   defaults to :name. :field is useful for adapters
    #   :property or nil use the actual Property object.
    #
    # @return [Hash]
    #   All the attributes
    #
    # @api public
    def attributes(key_on = :name)
      attributes = {}
      properties.each do |property|
        if model.public_method_defined?(name = property.name)
          key = case key_on
            when :name  then name
            when :field then property.field
            else             property
          end

          attributes[key] = send(name)
        end
      end
      attributes
    end

    # Assign values to multiple attributes in one call (mass assignment)
    #
    # @param [Hash] attributes
    #   names and values of attributes to assign
    #
    # @return [Hash]
    #   names and values of attributes assigned
    #
    # @api public
    def attributes=(attributes)
      attributes.each do |name, value|
        case name
          when String, Symbol
            if model.public_method_defined?(setter = "#{name}=")
              send(setter, value)
            else
              raise ArgumentError, "The attribute '#{name}' is not accessible in #{model}"
            end
          when Associations::Relationship, Property
            name.set(self, value)
        end
      end
    end

    # Reloads association and all child association
    #
    # @return [Resource]
    #   the receiver, the current Resource instance
    #
    # @api public
    def reload
      if saved?
        eager_load(loaded_properties)
        child_relationships.each { |relationship| relationship.get!(self).reload }
      end

      self
    end

    # Updates attributes and saves this Resource instance
    #
    # @param [Hash] attributes
    #   attributes to be updated
    #
    # @return [Boolean]
    #   true if resource and storage state match
    #
    # @api public
    chainable do
      def update(attributes = {})
        assert_update_clean_only(:update)
        self.attributes = attributes
        save
      end
    end

    # Updates attributes and saves this Resource instance, bypassing hooks
    #
    # @param [Hash] attributes
    #   attributes to be updated
    #
    # @return [Boolean]
    #   true if resource and storage state match
    #
    # @api public
    def update!(attributes = {})
      assert_update_clean_only(:update!)
      self.attributes = attributes
      save!
    end

    # Save the instance and loaded, dirty associations to the data-store
    #
    # @return [Boolean]
    #   true if Resource instance and all associations were saved
    #
    # @api public
    chainable do
      def save
        save_parents && save_self && save_children
      end
    end

    # Save the instance and loaded, dirty associations to the data-store, bypassing hooks
    #
    # @return [Boolean]
    #   true if Resource instance and all associations were saved
    #
    # @api public
    def save!
      save_parents(false) && save_self(false) && save_children(false)
    end

    # Destroy the instance, remove it from the repository
    #
    # @return [Boolean]
    #   true if resource was destroyed
    #
    # @api public
    chainable do
      def destroy
        destroy!
      end
    end

    # Destroy the instance, remove it from the repository, bypassing hooks
    #
    # @return [Boolean]
    #   true if resource was destroyed
    #
    # @api public
    def destroy!
      if saved? && repository.delete(Collection.new(query, [ self ])) == 1
        @destroyed = true
        @collection.delete(self) if @collection
        reset
        freeze
      end

      destroyed?
    end

    # Compares another Resource for equality
    #
    # Resource is equal to +other+ if they are the same object (identity)
    # or if they are both of the *same model* and all of their attributes
    # are equivalent
    #
    # @param [Resource] other
    #   the other Resource to compare with
    #
    # @return [Boolean]
    #   true if they are equal, false if not
    #
    # @api public
    def eql?(other)
      return true if equal?(other)
      instance_of?(other.class) && cmp?(other, :eql?)
    end

    # Compares another Resource for equivalency
    #
    # Resource is equal to +other+ if they are the same object (identity)
    # or if they are both of the *same base model* and all of their attributes
    # are equivalent
    #
    # @param [Resource] other
    #   the other Resource to compare with
    #
    # @return [Boolean]
    #   true if they are equivalent, false if not
    #
    # @api public
    def ==(other)
      return true if equal?(other)
      other.respond_to?(:model)                       &&
      model.base_model.equal?(other.model.base_model) &&
      cmp?(other, :==)
    end

    # Compares two Resources to allow them to be sorted
    #
    # @param [Resource] other
    #   The other Resource to compare with
    #
    # @return [Integer]
    #   Return 0 if Resources should be sorted as the same, -1 if the
    #   other Resource should be after self, and 1 if the other Resource
    #   should be before self
    #
    # @api public
    def <=>(other)
      unless other.kind_of?(model.base_model)
        raise ArgumentError, "Cannot compare a #{other.model} instance with a #{model} instance"
      end
      cmp = 0
      model.default_order(repository_name).each do |direction|
        cmp = direction.get(self) <=> direction.get(other)
        break if cmp != 0
      end
      cmp
    end

    # Returns hash value of the object.
    # Two objects with the same hash value assumed equal (using eql? method)
    #
    # DataMapper resources are equal when their models have the same hash
    # and they have the same set of properties
    #
    # When used as key in a Hash or Hash subclass, objects are compared
    # by eql? and thus hash value has direct effect on lookup
    #
    # @api private
    def hash
      key.hash
    end

    # Get a Human-readable representation of this Resource instance
    #
    #   Foo.new   #=> #<Foo name=nil updated_at=nil created_at=nil id=nil>
    #
    # @return [String]
    #   Human-readable representation of this Resource instance
    #
    # @api public
    def inspect
      # TODO: display relationship values
      attrs = properties.map do |property|
        value = if new? || property.loaded?(self)
          property.get!(self).inspect
        else
          '<not loaded>'
        end

        "#{property.instance_variable_name}=#{value}"
      end

      "#<#{model.name} #{attrs.join(' ')}>"
    end

    # Hash of original values of attributes that have unsaved changes
    #
    # @return [Hash]
    #   original values of attributes that have unsaved changes
    #
    # @api semipublic
    def original_attributes
      @original_attributes ||= {}
    end

    # Checks if an attribute has been loaded from the repository
    #
    # @example
    #   class Foo
    #     include DataMapper::Resource
    #
    #     property :name,        String
    #     property :description, Text,   :lazy => false
    #   end
    #
    #   Foo.new.attribute_loaded?(:description)   #=> false
    #
    # @return [Boolean]
    #   true if ivar +name+ has been loaded
    #
    # @return [Boolean]
    #   true if ivar +name+ has been loaded
    #
    # @api private
    def attribute_loaded?(name)
      properties[name].loaded?(self)
    end

    # Checks if an attribute has unsaved changes
    #
    # @param [Symbol] name
    #   name of attribute to check for unsaved changes
    #
    # @return [Boolean]
    #   true if attribute has unsaved changes
    #
    # @api semipublic
    def attribute_dirty?(name)
      dirty_attributes.key?(properties[name])
    end

    # Hash of attributes that have unsaved changes
    #
    # @return [Hash]
    #   attributes that have unsaved changes
    #
    # @api semipublic
    def dirty_attributes
      dirty_attributes = {}

      original_attributes.each_key do |property|
        dirty_attributes[property] = property.value(property.get!(self))
      end

      dirty_attributes
    end

    # Saves the resource
    #
    # @return [Boolean]
    #   true if the resource was successfully saved
    #
    # @api semipublic
    def save_self(safe = true)
      if safe
        new? ? create_hook : update_hook
      else
        new? ? _create : _update
      end
    end

    # Saves the parent resources
    #
    # @return [Boolean]
    #   true if the parents were successfully saved
    #
    # @api private
    def save_parents(safe = true)
      parent_relationships.all? do |relationship|
        parent = relationship.get!(self)
        if parent.dirty? ? parent.save_parents(safe) && parent.save_self(safe) : parent.saved?
          relationship.set(self, parent)  # set the FK values
        end
      end
    end

    # Saves the children resources
    #
    # @return [Boolean]
    #   true if the children were successfully saved
    #
    # @api private
    def save_children(safe = true)
      child_relationships.all? do |relationship|
        association = relationship.get!(self)
        safe ? association.save : association.save!
      end
    end

    # Reset the Resource to a similar state as a new record:
    # removes it from identity map and clears original property
    # values (thus making all properties non dirty)
    #
    # @api private
    def reset
      @saved = false
      identity_map.delete(key)
      original_attributes.clear
      self
    end

    # Gets a Collection with the current Resource instance as its only member
    #
    # @return [Collection, FalseClass]
    #   nil if this is a new record,
    #   otherwise a Collection with self as its only member
    #
    # @api private
    def collection
      return @collection if @collection || new? || frozen?
      @collection = Collection.new(query, [ self ])
    end

    protected

    # Method for hooking callbacks on resource creation
    #
    # @return [Boolean]
    #   true if the create was successful, false if not
    #
    # @api private
    def create_hook
      _create
    end

    # Method for hooking callbacks on resource updates
    #
    # @return [Boolean]
    #   true if the update was successful, false if not
    #
    # @api private
    def update_hook
      _update
    end

    private

    # Initialize a new instance of this Resource using the provided values
    #
    # @param [Hash] attributes
    #   attribute values to use for the new instance
    #
    # @return [Hash]
    #   attribute values used in the new instance
    #
    # @api public
    def initialize(attributes = {}, &block) # :nodoc:
      self.attributes = attributes
    end

    # Returns name of the repository this object
    # was loaded from
    #
    # @return [String]
    #   name of the repository this object was loaded from
    #
    # @api private
    def repository_name
      repository.name
    end

    # Gets this instance's Model's properties
    #
    # @return [Array(Property)]
    #   List of this Resource's Model's properties
    #
    # @api private
    def properties
      model.properties(repository_name)
    end

    # Gets this instance's Model's relationships
    #
    # @return [Array(Associations::Relationship)]
    #   List of this instance's Model's Relationships
    #
    # @api private
    def relationships
      model.relationships(repository_name)
    end

    # Returns the identity map for the model from the repository
    #
    # @return [IdentityMap]
    #   identity map of repository this object was loaded from
    #
    # @api semipublic
    def identity_map
      repository.identity_map(model)
    end

    # Fetches all the names of the attributes that have been loaded,
    # even if they are lazy but have been called
    #
    # @return [Array<Property>]
    #   names of attributes that have been loaded
    #
    # @api private
    def loaded_properties
      properties.select { |property| property.loaded?(self) }
    end

    # Lazy loads attributes not yet loaded
    #
    # @param [Array<Property>] fields
    #   the properties to reload
    #
    # @return [self]
    #
    # @api private
    def lazy_load(fields)
      eager_load(fields - loaded_properties)
    end

    # Reloads specified attributes
    #
    # @param [Array<Property>] fields
    #   the properties to reload
    #
    # @return [Resource]
    #   the receiver, the current Resource instance
    #
    # @api private
    def eager_load(fields)
      unless fields.empty? || new?
        collection.reload(:fields => fields)
      end

      self
    end

    # Gets a Query that will return this Resource instance
    #
    # @return [Query]
    #   Query that will retrieve this Resource instance
    #
    # @api private
    def query
      Query.new(repository, model, model.key_conditions(repository, key))
    end

    # TODO: document
    # @api private
    def parent_relationships
      parent_relationships = []

      relationships.each_value do |relationship|
        next unless relationship.respond_to?(:resource_for) && relationship.loaded?(self)
        next unless relationship.get(self)

        parent_relationships << relationship
      end

      parent_relationships
    end

    # Returns loaded child relationships
    #
    # @return [Array<Associations::OneToMany::Relationship>]
    #   array of child relationships for which this resource is parent and is loaded
    #
    # @api private
    def child_relationships
      child_relationships = []

      relationships.each_value do |relationship|
        next unless relationship.respond_to?(:collection_for) && relationship.loaded?(self)

        association = relationship.get!(self)
        next unless association.loaded? || association.head.any? || association.tail.any?

        child_relationships << relationship
      end

      many_to_many, other = child_relationships.partition do |relationship|
        relationship.kind_of?(Associations::ManyToMany::Relationship)
      end

      many_to_many + other
    end

    # Creates the resource with default values
    #
    # If resource is not dirty or a new (not yet saved),
    # this method returns false
    #
    # On successful save identity map of the repository is
    # updated
    #
    # Needs to be a protected method so that it is hookable
    #
    # The primary purpose of this method is to allow before :create
    # hooks to fire at a point just before/after resource creation
    #
    # @return [Boolean]
    #   true if the receiver was successfully created
    #
    # @api private
    def _create
      # Can't create a resource that is not dirty and doesn't have serial keys
      return false if new? && !dirty?

      # set defaults for new resource
      properties.each do |property|
        unless property.serial? || property.loaded?(self)
          property.set(self, property.default_for(self))
        end
      end

      repository.create([ self ])

      @repository = repository
      @saved      = true

      original_attributes.clear

      identity_map[key] = self

      true
    end

    # Updates resource state
    #
    # The primary purpose of this method is to allow before :update
    # hooks to fire at a point just before/after resource update whether
    # it is the result of Resource#save, or using Resource#update
    #
    # @return [Boolean]
    #   true if the receiver was successfully created
    #
    # @api private
    def _update
      dirty_attributes = self.dirty_attributes

      if dirty_attributes.empty?
        true
      elsif dirty_attributes.any? { |property, value| !property.nullable? && value.nil? }
        false
      else
        # remove from the identity map
        identity_map.delete(key)

        return false unless repository.update(dirty_attributes, Collection.new(query, [ self ])) == 1

        # remove the cached key in case it is updated
        remove_instance_variable(:@key)

        original_attributes.clear

        identity_map[key] = self

        true
      end
    end

    # Return true if +other+'s is equivalent or equal to +self+'s
    #
    # @param [Resource] other
    #   The Resource whose attributes are to be compared with +self+'s
    # @param [Symbol] operator
    #   The comparison operator to use to compare the attributes
    #
    # @return [Boolean]
    #   The result of the comparison of +other+'s attributes with +self+'s
    #
    # @api private
    def cmp?(other, operator)
      return false unless key.send(operator, other.key)
      return true if repository.send(operator, other.repository) && !dirty? && !other.dirty?

      # get all the loaded and non-loaded properties that are not keys,
      # since the key comparison was performed earlier
      loaded, not_loaded = properties.select { |property| !property.key? }.partition do |property|
        property.loaded?(self) && property.loaded?(other)
      end

      # check all loaded properties, and then all unloaded properties
      (loaded + not_loaded).all? { |property| property.get(self).send(operator, property.get(other)) }
    end

    # Raises an exception if #update is performed on a dirty resource
    #
    # @param [Symbol] method
    #   the name of the method to use in the exception
    #
    # @return [undefined]
    #
    # @raise [UpdateConflictError]
    #   raise if the resource is dirty
    #
    # @api private
    def assert_update_clean_only(method)
      if original_attributes.any?
        raise UpdateConflictError, "#{model}##{method} cannot be called on a dirty resource"
      end
    end
  end # module Resource
end # module DataMapper
