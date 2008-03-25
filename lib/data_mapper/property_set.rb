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
          end
        end
      end
    end
    
    alias __rb_select select
    def select(*args, &b)
      if block_given?
        super
      else
        args.map { |arg| self[arg] }.compact
      end
    end
    
    alias __rb_get_at_index []
    def [](i)
      if property = @cache_by_names[i]
        property
      else
        __rb_get_at_index(i)
      end
    end
    
    def defaults
      reject { |property| property.lazy? }
    end
    
    def key
      @key = select { |property| property.key? }
      def key
        @key
      end
      key
    end
  end
  
end