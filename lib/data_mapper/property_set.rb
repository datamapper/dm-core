module DataMapper
  class PropertySet
    include Enumerable

    def [](name)
      @property_for[name]
    end

    def slice(*names)
      @property_for.values_at(*names)
    end

    def add(*properties)
      @entries.push(*properties)
      self
    end

    alias << add

    def length
      @entries.length
    end

    def empty?
      @entries.empty?
    end

    def each(&block)
      @entries.each { |property| yield property }
      self
    end

    def defaults
      @defaults ||= reject { |property| property.lazy? }
    end

    def key
      @key ||= select { |property| property.key? }
    end

    def inheritance_property
      @inheritance_property ||= detect { |property| property.type == Class }
    end

    def get(resource)
      map { |property| property.get(resource) }
    end

    def set(values, resource)
      if Array === values
        raise ArgumentError, "+values+ must have a length of #{length}, but has #{values.length}", caller if values.length != length
      elsif !values.nil?
        raise ArgumentError, "+values+ must be nil or an Array, but was a #{values.class}", caller
      end
      each_with_index { |property,i| property.set(values.nil? ? nil : values[i], resource) }
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

      result =  []

      names = [ names ] if Symbol === names

      names.each do |name|
        contexts = property_contexts(name)
        if contexts.empty?
          result << name  # not lazy
        else
          contexts.each do |context|
            lazy_context(context).each do |field|
              result << field unless result.include?(field)
            end
          end
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

    private

    def initialize(properties = [], &block)
      raise ArgumentError, "+properties+ should be an Array, but was #{properties.class}", caller unless Array === properties

      @entries      = properties
      @property_for = Hash.new do |h,k|
        case k
          when Symbol
            if property = detect { |property| property.name == k }
              h[k.to_s] = h[k] = property
            end
          when String
            if property = detect { |property| property.name.to_s == k }
              h[k] = h[k.to_sym] = property
            end
          else
            raise "Key must be a Symbol or String, but was #{k.class}"
        end
      end
    end

    def lazy_contexts
      @lazy_contexts ||= Hash.new { |h,k| h[k] = [] }
    end

    def property_contexts(name)
      result = []
      lazy_contexts.each do |key,value|
        result << key if value.include?(name)
      end
      result
    end
  end # class PropertySet
end # module DataMapper
