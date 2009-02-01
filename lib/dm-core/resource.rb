module DataMapper
  module Resource
    include Extlib::Assertions

    ##
    # Appends a module for inclusion into the model class after
    # DataMapper::Resource.
    #
    # This is a useful way to extend DataMapper::Resource while still retaining
    # a self.included method.
    #
    # @param [Module] inclusions
    #   the module that is to be appended to the module after DataMapper::Resource
    #
    # @return [TrueClass, FalseClass]
    #   true if the inclusions have been successfully appended to the list
    #
    # @api semipublic
    def self.append_inclusions(*inclusions)
      extra_inclusions.concat inclusions
      true
    end

    # The current registered extra inclusions
    # @api private
    def self.extra_inclusions
      @extra_inclusions ||= []
    end

    # Makes sure a class gets all the methods when it includes Resource
    #
    # @api private
    # TODO: move logic to Model#extended
    def self.included(model)
      model.extend Model

      extra_inclusions.each { |inclusion| model.send(:include, inclusion) }

      descendants << model

      class << model
        @_valid_model = false
        attr_reader :_valid_model
      end
    end

    ##
    # Return all classes that include the DataMapper::Resource module
    #
    #   Class Foo
    #     include DataMapper::Resource
    #   end
    #
    #   DataMapper::Resource.descendants.to_a.first   #=> Foo
    #
    # @return [Set]
    #   Set containing the including classes
    #
    # @api semipublic
    def self.descendants
      @descendants ||= Set.new
    end

    # +---------------
    # Instance methods

    # TODO: document
    # @api private
    attr_writer :collection

    # TODO: document
    # @api public
    alias model class

    ##
    # Returns the value of the attribute.
    #
    # Do not read from instance variables directly, but use this method.
    # This method handles lazy loading the attribute and returning of
    # defaults if nessesary.
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
    # @param  [Symbol] name
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

    ##
    # Sets the value of the attribute and marks the attribute as dirty
    # if it has been changed so that it may be saved. Do not set from
    # instance variables directly, but use this method. This method
    # handles the lazy loading the property and returning of defaults
    # if nessesary.
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

    ##
    # Compares another Resource for equality
    #
    # Resource is equal to +other+ if they are the same object (identity)
    # or if they are both of the *same model* and all of their attributes
    # are equivalent
    #
    # @param [DataMapper::Resource] other
    #   the other Resource to compare with
    #
    # @return [TrueClass, FalseClass]
    #   true if they are equal, false if not
    #
    # @api public
    def eql?(other)
      if equal?(other)
        return true
      end

      unless self.class.equal?(other.class)
        return false
      end

      cmp?(other, :eql?)
    end

    ##
    # Compares another Resource for equivalency
    #
    # Resource is equal to +other+ if they are the same object (identity)
    # or if they are both of the *same base model* and all of their attributes
    # are equivalent
    #
    # @param [DataMapper::Resource] other
    #   the other Resource to compare with
    #
    # @return [TrueClass, FalseClass]
    #   true if they are equivalent, false if not
    #
    # @api public
    def ==(other)
      if equal?(other)
        return true
      end

      unless other.respond_to?(:model) && model.base_model.equal?(other.model.base_model)
        return false
      end

      cmp?(other, :==)
    end

    ##
    # Compares two Resources to allow them to be sorted
    #
    # @param [DataMapper::Resource] other
    #   The other Resource to compare with
    #
    # @return [Integer]
    #   Return 0 if Resources should be sorted as the same, -1 if the
    #   other Resource should be after self, and 1 if the other Resource
    #   should be before self
    #
    # @api public
    def <=>(other)
      unless other.kind_of?(model)
        raise ArgumentError, "Cannot compare a #{other.model} instance with a #{model} instance"
      end
      cmp = 0
      model.default_order(repository.name).map do |i|
        cmp = i.property.get!(self) <=> i.property.get!(other)
        cmp *= -1 if i.direction == :desc
        break if cmp != 0
      end
      cmp
    end

    ##
    # Get a Human-readable representation of this Resource instance
    #
    #   Foo.new   #=> #<Foo name=nil updated_at=nil created_at=nil id=nil>
    #
    # @return [String]
    #   Human-readable representation of this Resource instance
    #
    # @api public
    def inspect
      saved = saved?

      attrs = []

      properties.each do |property|
        value = if !property.loaded?(self) && saved
          '<not loaded>'
        else
          send(property.getter).inspect
        end

        attrs << "#{property.name}=#{value}"
      end

      "#<#{model.name} #{attrs * ' '}>"
    end

    ##
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
      @repository || model.repository
    end

    ##
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
      @key ||= model.key(repository.name).map do |property|
        original_values[property] || property.get!(self)
      end
    end

    ##
    # Checks if an attribute has been loaded from the repository
    #
    #   class Foo
    #     include DataMapper::Resource
    #     property :name, String
    #     property :description, Text, :lazy => false
    #   end
    #
    #   Foo.new.attribute_loaded?(:description)   #=> false
    #
    # @return [TrueClass, FalseClass]
    #   true if ivar +name+ has been loaded
    #
    # @return [TrueClass, FalseClass] true if ivar +name+ has been loaded
    #
    # @api private
    def attribute_loaded?(name)
      properties[name].loaded?(self)
    end

    ##
    # Fetches all the names of the attributes that have been loaded,
    # even if they are lazy but have been called
    #
    #   class Foo
    #     include DataMapper::Resource
    #     property :name, String
    #     property :description, Text, :lazy => false
    #   end
    #
    #   Foo.new.loaded_attributes   #=>  [:name]
    #
    # @return [Array(Symbol)]
    #   names of attributes that have been loaded
    #
    # @return [Array<Symbol>] names of attributes that have been loaded
    #
    # @api private
    def loaded_attributes
      loaded_attributes = properties.map { |p| p.name if p.loaded?(self) }
      loaded_attributes.compact!
      loaded_attributes
    end

    ##
    # Hash of original values of attributes that have unsaved changes
    #
    # @return [Hash]
    #   original values of attributes that have unsaved changes
    #
    # @api semipublic
    def original_values
      @original_values ||= {}
    end

    ##
    # Hash of attributes that have unsaved changes
    #
    # @return [Hash]
    #   attributes that have unsaved changes
    #
    # @api semipublic
    def dirty_attributes
      dirty_attributes = {}

      original_values.each_key do |property|
        dirty_attributes[property] = property.value(property.get!(self))
      end

      dirty_attributes
    end

    ##
    # Checks if the resource has unsaved changes
    #
    # @return
    #   [TrueClass, FalseClass] true if resource is new or has any unsaved changes
    #
    # @api semipublic
    def dirty?
      if dirty_attributes.any?
        true
      elsif new?
        model.identity_field || properties.any? { |p| p.default? }
      else
        false
      end
    end

    ##
    # Checks if an attribute has unsaved changes
    #
    # @param [Symbol] name
    #   name of attribute to check for unsaved changes
    #
    # @return [TrueClass, FalseClass]
    #   true if attribute has unsaved changes
    #
    # @api semipublic
    def attribute_dirty?(name)
      dirty_attributes.key?(properties[name])
    end

    # Gets a Collection with the current Resource instance as its only member
    #
    # @return [DataMapper::Collection, FalseClass]
    #   false if this is a new record,
    #   otherwise a Collection with self as its only member
    #
    # @api private
    def collection
      @collection ||= if saved?
        Collection.new(to_query, [ self ])
      end
    end

    ##
    # Reloads association and all child association
    #
    # @return [Resource]
    #   the receiver, the current Resource instance
    #
    # @api public
    def reload
      if saved?
        reload_attributes(*loaded_attributes)
        child_associations.each { |a| a.reload }
      end

      self
    end

    ##
    # Reloads specified attributes
    #
    # @param [Enumerable(Symbol)] attributes
    #   name(s) of attribute(s) to reload
    #
    # @return [Resource]
    #   the receiver, the current Resource instance
    #
    # @api private
    def reload_attributes(*attributes)
      unless attributes.empty? || new?
        collection.reload(:fields => attributes)
      end

      self
    end

    ##
    # Checks if this Resource instance is new
    #
    # @return [TrueClass, FalseClass]
    #   true if the resource is new and not saved
    #
    # @api public
    def new?
      !saved?
    end

    ##
    # Checks if this Resource instance has been saved
    #
    # @deprecated
    def new_record?
      warn "#{self.class}#new_record? is deprecated, use #{self.class}#new? instead"
      new?
    end

    ##
    # Checks if this Resource instance is saved
    #
    # @return [TrueClass, FalseClass]
    #   true if the resource has been saved
    #
    # @api public
    def saved?
      @saved == true
    end

    ##
    # Gets all the attributes of the Resource instance
    #
    # @return [Hash]
    #   All the (non)-lazy attributes
    #
    # @return [Hash]
    #   All the (non)-lazy attributes
    #
    # @api public
    def attributes
      attributes = {}
      properties.each do |property|
        if public_method?(getter = property.getter)
          attributes[property.name] = send(getter)
        end
      end
      attributes
    end

    ##
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
      attributes.each do |name,value|
        # XXX: is it common to have an attribute with a trailing question mark?
        name = name.to_s.sub(/\?\z/, '')
        if public_method?(setter = "#{name}=")
          send(setter, value)
        else
          raise ArgumentError, "The property '#{name}' is not accessible in #{self.class}"
        end
      end
    end

    ##
    # Deprecated API for updating attributes and saving Resource
    #
    # @see #update
    #
    # @api public
    def update_attributes(attributes = {}, *allowed)
      warn "#{self.class}#update_attributes is deprecated, use #{self.class}#update instead"

      if allowed.any?
        warn "specifying allowed in #{self.class}#update_attributes is deprecated," \
          'use Hash#only to filter the attributes in the caller'
        attributes = attributes.only(*allowed)
      end

      update(attributes, *allowed)
    end

    ##
    # Updates attributes and saves this Resource instance
    #
    # @param  [Hash]  attributes
    #   attributes to be updated
    #
    # @return [TrueClass, FalseClass]
    #   true if resource and storage state match
    #
    # @api public
    def update(attributes = {})
      assert_kind_of 'attributes', attributes, Hash

      self.attributes = attributes

      _update
    end

    ##
    # Save the instance and associated children to the data-store.
    #
    # This saves all children in a has n relationship (if they're dirty).
    #
    # @return [TrueClass, FalseClass]
    #   true if Resource instance and all associations were saved
    #
    # @see DataMapper::Repository#save
    #
    # @api public
    def save(context = :default)
      # Takes a context, but does nothing with it. This is to maintain the
      # same API through out all of dm-more. dm-validations requires a
      # context to be passed

      unless saved = new? ? _create : _update
        return false
      end

      child_associations.all? { |a| a.save }
    end

    ##
    # Destroy the instance, remove it from the repository
    #
    # @return [TrueClass, FalseClass]
    #   true if resource was destroyed
    #
    # @api public
    def destroy
      if saved? && repository.delete(to_query) == 1
        reset
        true
      else
        false
      end
    end

    # Gets a Query that will return this Resource instance
    #
    # @return [Query] Query that will retrieve this Resource instance
    #
    # @api private
    def to_query
      model.to_query(repository, key)
    end

    ##
    # Reset the Resource to a similar state as a new record
    #
    # @api private
    def reset
      @saved = false
      repository.identity_map(model).delete(key)
      original_values.clear
    end

    protected

    ##
    # Saves this Resource instance to the repository,
    # setting default values for any unset properties
    #
    # Needs to be a protected method so that it is hookable
    #
    # @return [TrueClass, FalseClass]
    #   true if the receiver was successfully created
    #
    # @api semipublic
    def _create
      # Can't create a resource that is not dirty and doesn't have serial keys
      if new? && !dirty?
        return false
      end

      # set defaults for new resource
      properties.each do |property|
        unless property.serial? || property.loaded?(self)
          property.set(self, property.default_for(self))
        end
      end

      if repository.create([ self ]) != 1
        return false
      end

      @repository = repository
      @saved      = true

      original_values.clear

      repository.identity_map(model)[key] = self

      true
    end

    # TODO: document
    # @api semipublic
    def _update
      # retrieve the attributes that need to be persisted
      dirty_attributes = self.dirty_attributes

      if dirty_attributes.empty?
        true
      elsif dirty_attributes.any? { |p,v| !p.nullable? && v.nil? }
        false
      elsif repository.update(dirty_attributes, to_query) != 1
        false
      else
        original_values.clear

        repository.identity_map(model)[key] = self

        true
      end
    end

    # Gets this instance's Model's properties
    #
    # @return [Array(Property)]
    #   List of this Resource's Model's properties
    #
    # @api private
    def properties
      model.properties(repository.name)
    end

    # Gets this instance's Model's relationships
    #
    # @return [Array(Associations::Relationship)]
    #   List of this instance's Model's Relationships
    #
    # @api private
    def relationships
      model.relationships(repository.name)
    end

    private

    ##
    # Initialize a new instance of this Resource using the provided values
    #
    # @param  [Hash]  attributes
    #   attribute values to use for the new instance
    #
    # @return [Resource]
    #   the newly initialized resource instance
    #
    # @api public
    def initialize(attributes = {}) # :nodoc:
      assert_valid_model
      @saved = false
      self.attributes = attributes
    end

    # TODO: move to Model#assert_valid
    # @api private
    def assert_valid_model # :nodoc:
      if self.class._valid_model
        return
      end

      properties = self.properties

      if properties.empty? && relationships.empty?
        raise IncompleteResourceError, "#{model.name} must have at least one property or relationship to be initialized."
      end

      if properties.key.empty?
        raise IncompleteResourceError, "#{model.name} must have a key."
      end

      self.class.instance_variable_set("@_valid_model", true)
    end

    # TODO: document
    # @api private
    def lazy_load(name)
      reload_attributes(*properties.lazy_load_context(name) - loaded_attributes)
    end

    # TODO: document
    # @api private
    def child_associations
      @child_associations ||= []
    end

    ##
    # Return true if the accesor or mutator +method+ is publicly accessible
    #
    # @param [String, Symbol] method
    #   The name of accessor or mutator to test
    #
    # @return [TrueClass, FalseClass]
    #   true if the accessor or mutator +method+ is public
    #
    # @api private
    def public_method?(method)
      model.public_method_defined?(method)
    end

    ##
    # Return true if +other+'s is equivalent or equal to +self+'s
    #
    # @param [Resource] other
    #   The Resource whose attributes are to be compared with +self+'s
    # @param [Symbol] operator
    #   The comparison operator to use to compare the attributes
    #
    # @return [TrueClass, FalseClass]
    #   The result of the comparison of +other+'s attributes with +self+'s
    #
    # @api private
    def cmp?(other, operator)
      unless key.send(operator, other.key)
        return false
      end

      if repository.send(operator, other.repository) && !dirty? && !other.dirty?
        return true
      end

      # get all the loaded and non-loaded properties that are not keys,
      # since the key comparison was performed earlier
      loaded, not_loaded = properties.select { |p| !p.key? }.partition do |property|
        property.loaded?(self) && property.loaded?(other)
      end

      # check all loaded properties, and then all unloaded properties
      (loaded + not_loaded).all? { |p| p.get(self).send(operator, p.get(other)) }
    end
  end # module Resource
end # module DataMapper
