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
      @defaults || @defaults = reject { |property| property.lazy? }
    end

    def key
      @key || @key = select { |property| property.key? }
    end

    def dup
      clone = PropertySet.new
      each { |property| clone << property }
      clone
    end

    def lazy_loaded
      @lazy_loaded || @lazy_loaded = LazyLoadedContexts.new
    end
  end




  class LazyLoadedContexts
      # A hash that contains all the named contexts
      #
      def contexts
        @contexts ||= @contexts = {}
      end

      # Return an array of DM::Property for a named context
      #
      def context(name)
        contexts[name] = [] unless contexts.has_key?(name)
        contexts[name]
      end

      # Clear all named context validators off of the resource
      #
      def clear!
        contexts.clear
      end

      # Return an array of context names for this property
      #
      def field_contexts(name)
        result = []
        contexts.map do |key,value|
          result << key if value.include?(name)
        end
        result
      end

      # Return a super set of property names to include in the lazy load where
      # the properties are part of the same context as the requested property
      # names
      #
      def expand_fields(name)
        result =  []

        raise ArgumentError("+name+ must be an Array of Symbols of a Symbol") unless name.is_a?(Array) || name.is_a?(Symbol)
        raise ArgumentError("+name+ cannot be an empty array") if name.is_a?(Array) && name.empty?

        if name.is_a?(Symbol)
          field_contexts(name).each do |ctx|
            context(ctx).each do |field|
              result << field unless result.include?(field)
            end
          end
        end

        if name.is_a?(Array)
          name.each do |n|
            field_contexts(n).each do |ctx|
              context(ctx).each do |field|
                result << field unless result.include?(field)
              end
            end
          end
        end

        result
      end
  end




end
