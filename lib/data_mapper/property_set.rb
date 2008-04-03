module DataMapper

  class PropertySet < Array
    def initialize
      super
      @cache_by_names = Hash.new do |h,k|
        detect do |property|
          if property.name == k
            h[k.to_s] = h[k] = property
          elsif property.name.to_s == k
            h[k] = h[k.to_sym] = property
          else
            nil
          end
        end
      end
    end

    def select(*args, &b)
      if block_given?
        super
      else
        args.map { |arg| @cache_by_names[arg] }.compact
      end
    end

    def detect(name = nil, &b)
      if block_given?
        super
      else
        @cache_by_names[name]
      end
    end

    def defaults
      @defaults ||= reject { |property| property.lazy? }
    end

    def key
      @key ||= select { |property| property.key? }
    end

    def value(instance)
      map { |p| p.value(instance) }
    end

    def set(value, instance)
      each_with_index { |p, i| p.set(value && value[i], instance) }
    end

    def to_hash(values)
      Hash[*zip(values).flatten]
    end

    def dup
      clone = PropertySet.new
      each { |property| clone << property }
      clone
    end

    def lazy_contexts
      @lazy_context ||= {}
    end

    def lazy_context(name)
      lazy_contexts[name] = [] unless lazy_contexts.has_key?(name)
      lazy_contexts[name]
    end

    def property_contexts(name)
      result = []
      lazy_contexts.map do |key,value|
        result << key if value.include?(name)
      end
      result
    end

    def lazy_load_context(names)
      result =  []

      raise ArgumentError("+name+ must be an Array of Symbols of a Symbol") unless names.is_a?(Array) || names.is_a?(Symbol)
      raise ArgumentError("+name+ cannot be an empty array") if names.is_a?(Array) && names.empty?

      if names.is_a?(Symbol)
        ctx = property_contexts(names)
        result << names if ctx.blank?  # not lazy
        ctx.each do |c|
          lazy_context(c).each do |field|
            result << field unless result.include?(field)
          end
        end
      end

      if names.is_a?(Array)
        names.each do |n|
          ctx = property_contexts(n)
          result << n if ctx.blank?  # not lazy
          ctx.each do |c|
            lazy_context(c).each do |field|
              result << field unless result.include?(field)
            end
          end
        end
      end

      result
    end
  end # class PropertySet
end # module DataMapper
