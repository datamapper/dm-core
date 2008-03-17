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
    def get(klass, key)
      @cache[mapped_class(klass)][key]
    end

    # Pass an instance to add it to the IdentityMap.
    # The instance must have an assigned key.
    def set(instance)
      key = instance.class.key(instance.loaded_set.repository).map do |property|
        instance.instance_variable_get(property.instance_variable_name)
      end
      
      raise "Can't store an instance with a nil key in the IdentityMap" if key.empty?
      
      @cache[mapped_class(instance.class)][key] = instance
    end
    
    # Remove an instance from the IdentityMap.
    def delete(instance)
      @cache[mapped_class(instance.class)].delete(instance.key)
    end
    
    # Clears a particular set of classes from the IdentityMap.
    def clear!(klass)
      @cache.delete(klass)
    end
    
    private
    def mapped_class(klass)
      unless klass.superclass.respond_to?(:persistent?)
        klass
      else
        mapped_class(klass.superclass)
      end
    end
  end
end
