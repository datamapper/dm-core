module DataMapper
  # Set of Property objects, used to associate
  # queries with set of fields it performed over,
  # to represent composite keys (esp. for associations)
  # and so on.
  class PropertySet < Array
    extend Deprecate

    deprecate :has_property?, :named?
    deprecate :slice,         :values_at
    deprecate :add,           :<<

    # @api semipublic
    def [](name)
      @properties[name]
    end

    alias superclass_slice []=
    private :superclass_slice

    # @api semipublic
    def []=(name, property)
      self << property
    end

    # @api semipublic
    def named?(name)
      @properties.key?(name)
    end

    # @api semipublic
    def values_at(*names)
      @properties.values_at(*names)
    end

    # @api semipublic
    def <<(property)
      found = named?(property.name)
      add_property(property)

      if found
        superclass_slice(index(property), property)
      else
        super
      end
    end

    # @api semipublic
    def include?(property)
      named?(property.name)
    end

    # @api semipublic
    def index(property)
      each_index { |index| break index if at(index).name == property.name }
    end

    # TODO: make PropertySet#reject return a PropertySet instance
    # @api semipublic
    def defaults
      @defaults ||= self.class.new(key | [ discriminator ].compact | reject { |property| property.lazy? }).freeze
    end

    # @api semipublic
    def key
      @key ||= self.class.new(select { |property| property.key? }).freeze
    end

    # @api semipublic
    def discriminator
      @discriminator ||= detect { |property| property.type == Types::Discriminator }
    end

    # @api semipublic
    def indexes
      index_hash = {}
      each { |property| parse_index(property.index, property.field, index_hash) }
      index_hash
    end

    # @api semipublic
    def unique_indexes
      index_hash = {}
      each { |property| parse_index(property.unique_index, property.field, index_hash) }
      index_hash
    end

    # @api semipublic
    def get(resource)
      map { |property| property.get(resource) }
    end

    # @api semipublic
    def get!(resource)
      map { |property| property.get!(resource) }
    end

    # @api semipublic
    def set(resource, values)
      zip(values) { |property, value| property.set(resource, value) }
    end

    # @api semipublic
    def set!(resource, values)
      zip(values) { |property, value| property.set!(resource, value) }
    end

    # @api semipublic
    def loaded?(resource)
      all? { |property| property.loaded?(resource) }
    end

    # @api semipublic
    def valid?(values)
      zip(values.nil? ? [] : values).all? { |property, value| property.valid?(value) }
    end

    # @api semipublic
    def typecast(values)
      zip(values.nil? ? [] : values).map { |property, value| property.typecast(value) }
    end

    # @api private
    def property_contexts(property)
      contexts = []
      lazy_contexts.each do |context, properties|
        contexts << context if properties.include?(property)
      end
      contexts
    end

    # @api private
    def lazy_context(context)
      lazy_contexts[context] ||= []
    end

    # @api private
    def in_context(properties)
      properties_in_context = properties.map do |property|
        if (contexts = property_contexts(property)).any?
          lazy_contexts.values_at(*contexts)
        else
          property
        end
      end

      properties_in_context.flatten.uniq
    end

    private

    # @api semipublic
    def initialize(*)
      super
      @properties = map { |property| [ property.name, property ] }.to_mash
    end

    # @api private
    def initialize_copy(*)
      super
      @properties = @properties.dup
    end

    # @api private
    def add_property(property)
      clear_cache
      @properties[property.name] = property
    end

    # @api private
    def clear_cache
      @defaults, @key, @discriminator = nil
    end

    # @api private
    def lazy_contexts
      @lazy_contexts ||= {}
    end

    # @api private
    def parse_index(index, property, index_hash)
      case index
        when true
          index_hash[property] = [ property ]
        when Symbol
          index_hash[index] ||= []
          index_hash[index] << property
        when Array
          index.each { |idx| parse_index(idx, property, index_hash) }
      end
    end
  end # class PropertySet
end # module DataMapper
