module DataMapper
  
  # Tracks objects to help ensure that each object gets loaded only once.
  # See: http://www.martinfowler.com/eaaCatalog/identityMap.html
  class IdentityMap
    
    def initialize(second_level_cache = nil)
      @second_level_cache = second_level_cache
      @cache = if second_level_cache.nil?
        Hash.new { |h,k| h[k] = Hash.new }
      else
        Hash.new { |h,k| h[k] = Hash.new { |h2,k2| h2[k2] = @second_level_cache.get(k, k2) } }
      end
    end

    # Pass a Class and a key, and to retrieve an instance.
    # If the instance isn't found, nil is returned.
    def get(resource, key)
      @cache[resource][key]
    end

    # Pass an instance to add it to the IdentityMap.
    # The instance must have an assigned key.
    def set(instance)
      # TODO could we not cause a nasty bug by dropping nil value keys when the 
      # user is using composite keys? Should we not rather raise an error if
      # the value is nil?
      key = instance.key
           
      raise ArgumentError.new("+key+ must be an Array, and can not be empty") if key.empty?       
      @cache[instance.class][key] = instance      
    end
    
    # Remove an instance from the IdentityMap.
    def delete(resource, key)
      @cache[resource].delete(key)
    end
    
    # Clears a particular set of classes from the IdentityMap.
    def clear!(resource)
      @cache.delete(resource)
    end
    
  end
end
