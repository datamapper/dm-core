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

    # TODO: document
    # @api semipublic
    def [](name)
      @properties[name]
    end

    alias super_slice []=

    # TODO: document
    # @api semipublic
    def []=(name, property)
      if named?(name)
        add_property(property)
        super_slice(index(property), property)
      else
        self << property
      end
    end

    # TODO: document
    # @api semipublic
    def named?(name)
      @properties.key?(name)
    end

    # TODO: document
    # @api semipublic
    def values_at(*names)
      @properties.values_at(*names)
    end

    # TODO: document
    # @api semipublic
    def <<(property)
      if named?(property.name)
        add_property(property)
        super_slice(index(property), property)
      else
        add_property(property)
        super
      end
    end

    # TODO: document
    # @api semipublic
    def include?(property)
      named?(property.name)
    end

    # TODO: make PropertySet#reject return a PropertySet instance
    # TODO: document
    # @api semipublic
    def defaults
      @defaults ||= self.class.new(key | [ discriminator ].compact | reject { |property| property.lazy? }).freeze
    end

    # TODO: document
    # @api semipublic
    def key
      @key ||= self.class.new(select { |property| property.key? }).freeze
    end

    # TODO: document
    # @api semipublic
    def discriminator
      @discriminator ||= detect { |property| property.type == Types::Discriminator }
    end

    # TODO: document
    # @api semipublic
    def indexes
      index_hash = {}
      each { |property| parse_index(property.index, property.field, index_hash) }
      index_hash
    end

    # TODO: document
    # @api semipublic
    def unique_indexes
      index_hash = {}
      each { |property| parse_index(property.unique_index, property.field, index_hash) }
      index_hash
    end

    # TODO: document
    # @api semipublic
    def get(resource)
      map { |property| property.get(resource) }
    end

    # TODO: document
    # @api semipublic
    def get!(resource)
      map { |property| property.get!(resource) }
    end

    # TODO: document
    # @api semipublic
    def set(resource, values)
      zip(values) { |property, value| property.set(resource, value) }
    end

    # TODO: document
    # @api semipublic
    def set!(resource, values)
      zip(values) { |property, value| property.set!(resource, value) }
    end

    # TODO: document
    # @api semipublic
    def loaded?(resource)
      all? { |property| property.loaded?(resource) }
    end

    # TODO: document
    # @api semipublic
    def typecast(values)
      zip(values.nil? ? [] : values).map { |property, value| property.typecast(value) }
    end

    # TODO: document
    # @api private
    def property_contexts(property)
      contexts = []
      lazy_contexts.each do |context, properties|
        contexts << context if properties.include?(property)
      end
      contexts
    end

    # TODO: document
    # @api private
    def lazy_context(context)
      lazy_contexts[context] ||= []
    end

    # TODO: document
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

    # TODO: document
    # @api semipublic
    def initialize(*)
      super
      @properties = map { |property| [ property.name, property ] }.to_mash
    end

    # TODO: document
    # @api private
    def initialize_copy(*)
      super
      @properties = @properties.dup
    end

    # TODO: document
    # @api private
    def add_property(property)
      clear_cache
      @properties[property.name] = property
    end

    # TODO: document
    # @api private
    def clear_cache
      @defaults, @key, @discriminator = nil
    end

    # TODO: document
    # @api private
    def lazy_contexts
      @lazy_contexts ||= {}
    end

    # TODO: document
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
