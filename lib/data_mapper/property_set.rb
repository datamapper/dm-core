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
        begin
          __rb_get_at_index(i)
        rescue RuntimeError => re
          puts "Expected index but got #{i.inspect}"
          raise re
        end
      end
    end
    
    def defaults
      reject { |property| property.lazy? }
    end
    
    def key
      @key = select { |property| property.key? }

      class << self
        def key
          @key
        end
      end
      
      key
    end
    
    def dup
      clone = PropertySet.new
      each { |property| clone << property }
      clone
    end
  end
  
end