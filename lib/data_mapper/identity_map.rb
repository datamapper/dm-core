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

    # Pass a Class and a key, and to retrieve a resource.
    # If the resource isn't found, nil is returned.
    def get(model, key)
      @cache[model][key]
    end

    # Pass a resource to add it to the IdentityMap.
    # The resource must have an assigned key.
    def set(resource)
      # TODO could we not cause a nasty bug by dropping nil value keys when the 
      # user is using composite keys? Should we not rather raise an error if
      # the value is nil?
      key = resource.key
      raise ArgumentError.new("+key+ must be an Array, and can not be empty") if key.empty?
      @cache[resource.class][key] = resource
    end

    # Remove a resource from the IdentityMap.
    def delete(model, key)
      @cache[model].delete(key)
    end
    
    # Clears a particular set of classes from the IdentityMap.
    def clear!(model)
      @cache.delete(model)
    end
    
  end # class IdentityMap
end # module DataMapper
