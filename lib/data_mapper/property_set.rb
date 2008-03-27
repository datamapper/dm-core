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
  end
  
end