module DataMapper
  
  class PropertySet < Array
    def initialize
      super
      @cache_by_names = Hash.new { |h,k| h[k] = detect { |property| property.name == k } }
    end
    
    def name(name)
      @cache_by_names[name]
    end
  end
  
end