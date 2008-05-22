module DataMapper
  class PropertySet
    include Enumerable

    def [](name)
      @property_for[name]
    end

    alias has_property? []

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

    def inheritance_property
      detect { |property| property.type == DataMapper::Types::Discriminator }
    end

    def get(resource)
      map { |property| property.get(resource) }
    end

    def set(resource, values)
      raise ArgumentError, "+resource+ should be a DataMapper::Resource, but was #{resource.class}" unless Resource === resource
      if Array === values
        raise ArgumentError, "+values+ must have a length of #{length}, but has #{values.length}", caller if values.length != length
      elsif !values.nil?
        raise ArgumentError, "+values+ must be nil or an Array, but was a #{values.class}", caller
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
      if Array === names
        raise ArgumentError, "+names+ cannot be an empty Array", caller if names.empty?
      elsif !(Symbol === names)
        raise ArgumentError, "+names+ must be a Symbol or an Array of Symbols, but was a #{names.class}", caller
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

    def to_query(values)
      Hash[ *zip(values).flatten ]
    end

    def inspect
      '#<PropertySet:{' + map { |property| property.inspect }.join(',') + '}>'
    end

    def dup(target = nil)
      return super() unless target

      properties = map do |property|
        # TODO: remove this hack once most in-the-wild code has switched
        # over to using Integer instead of Fixnum for properties
        type = property.type
        type = Integer if Fixnum == type
        Property.new(target || property.model, property.name, type, property.options.dup)
      end

      self.class.new(properties)
    end

    private

    def initialize(properties = [])
      raise ArgumentError, "+properties+ should be an Array, but was #{properties.class}", caller unless Array === properties

      @entries = properties
      @property_for = hash_for_property_for
    end

    def initialize_copy(orig)
      @entries = orig.entries.dup
      @property_for = hash_for_property_for
    end

    def hash_for_property_for
      Hash.new do |h,k|
        raise "Key must be a Symbol or String, but was #{k.class}" unless [String, Symbol].include?(k.class)

        ksym = k.to_sym
        if property = detect { |property| property.name == ksym }
          h[ksym] = h[k.to_s] = property
        end
      end
    end

    def lazy_contexts
      @lazy_contexts ||= Hash.new { |h,context| h[context] = [] }
    end

  end # class PropertySet
end # module DataMapper
