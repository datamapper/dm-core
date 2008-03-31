require __DIR__ + 'support/string'
require __DIR__ + 'property_set'
require __DIR__ + 'property'
require __DIR__ + 'repository'
require __DIR__ + 'hook'
require __DIR__ + 'associations/relationship'
require __DIR__ + 'associations/association_set'
require __DIR__ + 'associations/belongs_to'
require __DIR__ + 'associations/has_one'
require __DIR__ + 'associations/has_many'
require __DIR__ + 'associations/has_and_belongs_to_many'

module DataMapper

  module Resource

    # +----------------------
    # Resource module methods

    def self.included(target)
      target.send(:extend, ClassMethods)
      target.send(:extend, DataMapper::Hook::ClassMethods)
      target.send(:include, DataMapper::Hook)
      target.instance_variable_set("@resource_names", Hash.new { |h,k| h[k] = repository(k).adapter.resource_naming_convention.call(target.name) })
      target.instance_variable_set("@properties", Hash.new { |h,k| h[k] = (k == :default ? PropertySet.new : h[:default].dup) })

      # Associations:
      target.send(:extend, DataMapper::Associations::BelongsTo)
      target.send(:extend, DataMapper::Associations::HasOne)
      target.send(:extend, DataMapper::Associations::HasMany)
      target.send(:extend, DataMapper::Associations::HasAndBelongsToMany)
    end

    def self.dependencies
      @dependencies = DependencyQueue.new
      def self.dependencies
        @dependencies
      end
      @dependencies
    end

    # +---------------
    # Instance methods

    def repository
      @loaded_set ? @loaded_set.repository : self.class.repository
    end

    def key
      key = []
      self.class.key(repository.name).map do |property|
        value = instance_variable_get(property.instance_variable_name)
        key << value if !value.nil?
      end
      key
    end

    def loaded_set
      @loaded_set
    end

    def loaded_set=(value)
      @loaded_set = value
    end

    def readonly!
      @readonly = true
    end

    def readonly?
      @readonly == true
    end

    def save
      repository.save(self)
    end

    def destroy
      repository.destroy(self)
    end

    def loaded_attributes
      # We don't assign a default to the Hash on purpose!!!
      @loaded_attributes || @loaded_attributes = Hash.new { |h,k| k.to_s.ensure_starts_with('@') }
    end
    
    def attribute_loaded?(name)
      raise ArgumentError.new("#{name.inspect} should be a Symbol") unless name.is_a?(Symbol)
      loaded_attributes.key?(name)
    end

    def dirty_attributes
      @dirty_attributes || @dirty_attributes = Hash.new
    end

    def dirty?
      !@dirty_attributes.blank?
    end

    def attribute_dirty?(name)
      raise ArgumentError.new("#{name.inspect} should be a Symbol") unless name.is_a?(Symbol)
      dirty_attributes.include?(name)
    end

    def attribute_get(name)
      ivar_name = loaded_attributes[name]
      
      unless attribute_loaded?(name)
        lazy_load!(name)
      end

      instance_variable_get(ivar_name)
    end
    
    def attribute_set(name, value)
      ivar_name = name.to_s.ensure_starts_with('@')
      property = self.class.properties(repository.name).detect(name)

      if property && property.lock?
        instance_variable_set(name.to_s.ensure_starts_with('@shadow_'), instance_variable_get(ivar_name))
      end

      loaded_attributes[name] = ivar_name
      dirty_attributes[name] = instance_variable_set(ivar_name, value)
    end
    
    def shadow_attribute_get(name)
      instance_variable_get(name.to_s.ensure_starts_with('@shadow_'))
    end

    def lazy_load!(*names)
      fields = self.class.properties(self.class.repository.name).lazy_load_context(names)
      
      unless new_record? || @loaded_set.nil?
        @loaded_set.reload!(:fields => fields)
      else
        fields.each { |name| attribute_set(name, nil) }
      end
    end

    def initialize(details = nil) # :nodoc:
      validate_resource!

      def initialize(details = nil)
        if details
          initialize_with_attributes(details)
        end
      end

      initialize(details)
    end

    def initialize_with_attributes(details) # :nodoc:
      case details
      when Hash then self.attributes = details
      when Resource, Struct then self.private_attributes = details.attributes
      # else raise ArgumentError.new("details should be a Hash, Resource or Struct\n\t#{details.inspect}")
      end
    end

    def validate_resource! # :nodoc:
      if self.class.properties(self.class.default_repository_name).empty?
        raise IncompleteResourceError.new("Resources must have at least one property to be initialized.")
      end
    end

    def self.===(other)
      other.is_a?(Module) && other.ancestors.include?(Resource)
    end

    # Returns <tt>true</tt> if this model hasn't been saved to the
    # database, <tt>false</tt> otherwise.
    def new_record?
      @new_record.nil? || @new_record
    end

    def attributes
      pairs = {}

      self.class.properties(repository.name).each do |property|
        if property.reader_visibility == :public
          pairs[property.name] = send(property.getter)
        end
      end

      pairs
    end

    # Mass-assign mapped fields.
    def attributes=(values_hash)
      values_hash.each_pair do |k,v|
        setter = k.to_s.sub(/\?$/, '').ensure_ends_with('=')
        # We check #public_methods and not Class#public_method_defined? to
        # account for singleton methods.
        if public_methods.include?(setter)
          send(setter, v)
        end
      end
    end

    private

    def private_attributes
      pairs = {}

      self.class.properties(repository.name).each do |property|
        pairs[property.name] = send(property.getter)
      end

      pairs
    end

    def private_attributes=(values_hash)
      values_hash.each_pair do |k,v|
        setter = k.to_s.sub(/\?$/, '').ensure_ends_with('=')
        if respond_to?(setter) || private_methods.include?(setter)
          send(setter, v)
        end
      end
    end

    public

    module ClassMethods

      def repository(name = default_repository_name)
        DataMapper::repository(name)
      end

      def default_repository_name
        :default
      end

      def resource_name(repository_name)
        @resource_names[repository_name]
      end

      def resource_names
        @resource_names
      end

      def property(name, type, options = {})
        property = Property.new(self, name, type, options)
        properties(repository.name) << property

        # Add property to the other mappings as well if this is for the default repository.
        if repository.name == default_repository_name
          @properties.each_pair do |repository_name, properties|
            next if repository_name == default_repository_name
            properties << property
          end
        end

        #Add the property to the lazy_loads set for this resources repository only
        # TODO Is this right or should we add the lazy contexts to all repositories?
        if type == Text || options.has_key?(:lazy)
          ctx = options.has_key?(:lazy) ? options[:lazy] : :default
          ctx = :default if ctx.is_a?(TrueClass)
          @properties[repository.name].lazy_context(ctx) << name if ctx.is_a?(Symbol)
          if ctx.is_a?(Array)
            ctx.each do |item|
              @properties[repository.name].lazy_context(item) << name
            end
          end
        end

        property
      end

      def properties(repository_name)
        @properties[repository_name]
      end

      def key(repository_name)
        @properties[repository_name].key
      end

      def inheritance_property(repository_name)
        @properties[repository_name].detect { |property| property.type == Class }
      end

      def get(*key)
        repository.get(self, key)
      end

      def [](key)
        get(key) || raise(ObjectNotFoundError, "Could not find #{self.name} with key: #{key.inspect}")
      end

      def all(options = {})
        repository(options[:repository] || default_repository_name).all(self, options)
      end

      def first(options = {})
        repository(options[:repository] || default_repository_name).first(self, options)
      end

      def create(values)
        instance = new(values)

        [instance, instance.save]
      end

      # TODO SPEC
      def copy(source, destination, options = {})
        repository(destination) do
          repository(source).all(self, options).each do |instance|
            self.create(instance)
          end
        end
      end
    end
  end
end
