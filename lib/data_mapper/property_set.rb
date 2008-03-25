module DataMapper
  
  class PropertySet < Array
    def initialize
      super
      @cache_by_names = Hash.new do |h,k|
        if match = detect { |property| property.name.to_s == k.to_s }
          h[k.to_s] = h[k.to_sym] = match
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
  end
  
end