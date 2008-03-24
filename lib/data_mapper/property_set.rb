module DataMapper
  
  class PropertySet < Array
    def initialize
      super
      @cache_by_names = Hash.new { |h,k| h[k] = detect { |property| property.name == k } }
    end
    
    def name(name)
      @cache_by_names[name]
    end
    
    alias __rb_select select
    def select(*args, &b)
      if block_given?
        super
      else
        __rb_select { |property| args.include?(property.name) }
      end
    end
  end
  
end