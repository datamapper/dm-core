module DataMapper
  class PropertySet
    include Assertions
    include Enumerable

    def [](name)
      @property_for[name] || raise(ArgumentError, "Unknown property '#{name}'", caller)
    end

    def []=(name, property)
      if existing_property = detect { |p| p.name == name }
        property.hash
        @entries[@entries.index(existing_property)] = property
      else
        add(property)
      end
      property
    end

    def has_property?(name)
      !!@property_for[name]
    end

    def slice(*names)
      @property_for.values_at(*names)
    end

    def add(*properties)
      @entries.push(*properties)
      properties.each { |property| property.hash }
      self
    end

    alias << add

    def length
      @entries.length
    end

    def empty?
      @entries.empty?
    end

    def each
      @entries.each { |property| yield property }
      self
    end

    def defaults
      reject { |property| property.lazy? }
    end

    def key
      select { |property| property.key? }
    end

    def indexes
      index_hash = {}
      repository_name = repository.name
      each { |property| parse_index(property.index, property.field(repository_name), index_hash) }
      index_hash
    end

    def unique_indexes
      index_hash = {}
      repository_name = repository.name
      each { |property| parse_index(property.unique_index, property.field(repository_name), index_hash) }
      index_hash
    end

    def inheritance_property
      detect { |property| property.type == DataMapper::Types::Discriminator }
    end

    def get(resource)
      map { |property| property.get(resource) }
    end

    def set(resource, values)
      if values.kind_of?(Array) && values.length != length
        raise ArgumentError, "+values+ must have a length of #{length}, but has #{values.length}", caller
      end

      each_with_index { |property,i| property.set(resource, values.nil? ? nil : values[i]) }
    end

    def property_contexts(name)
      contexts = []
      lazy_contexts.each do |context,property_names|
        contexts << context if property_names.include?(name)
      end
      contexts
    end

    def lazy_context(name)
      lazy_contexts[name]
    end

    def lazy_load_context(names)
      if names.kind_of?(Array) && names.empty?
        raise ArgumentError, '+names+ cannot be empty', caller
      end

      result = []

      Array(names).each do |name|
        contexts = property_contexts(name)
        if contexts.empty?
          result << name  # not lazy
        else
          result |= lazy_contexts.values_at(*contexts).flatten.uniq
        end
      end
      result
    end

    def to_query(bind_values)
      Hash[ *zip(bind_values).flatten ]
    end

    def inspect
      '#<PropertySet:{' + map { |property| property.inspect }.join(',') + '}>'
    end

    private

    def initialize(properties = [])
      assert_kind_of 'properties', properties, Enumerable

      @entries = properties
      @property_for = hash_for_property_for
    end

    def initialize_copy(orig)
      @entries = orig.entries.dup
      @property_for = hash_for_property_for
    end

    def hash_for_property_for
      Hash.new do |h,k|
        ksym = k.to_sym
        if property = detect { |property| property.name == ksym }
          h[ksym] = h[k.to_s] = property
        end
      end
    end

    def lazy_contexts
      @lazy_contexts ||= Hash.new { |h,context| h[context] = [] }
    end

    def parse_index(index, property, index_hash)
      case index
      when true then index_hash[property] = [property]
      when Symbol
        index_hash[index.to_s] ||= []
        index_hash[index.to_s] << property
      when Enumerable then index.each { |idx| parse_index(idx, property, index_hash) }
      end
    end
  end # class PropertySet
end # module DataMapper
