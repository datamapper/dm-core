module DataMapper
  
  # Tracks objects to help ensure that each object gets loaded only once.
  # See: http://www.martinfowler.com/eaaCatalog/identityMap.html
  class IdentityMap
    
    def initialize
      # WeakHash is much more expensive, and not necessary if the IdentityMap is tied to Session instead of Repository.
      # @cache = Hash.new { |h,k| h[k] = Support::WeakHash.new }
      @cache = Hash.new { |h,k| h[k] = Hash.new }
    end

    # Pass a Class and a key, and to retrieve an instance.
    # If the instance isn't found, nil is returned.
    def get(klass, key)
      @cache[mapped_class(klass)][key]
    end

    # Pass an instance to add it to the IdentityMap.
    # The instance must have an assigned key.
    def set(instance)
      instance_key = instance.key
      raise "Can't store an instance with a nil key in the IdentityMap" if instance_key.nil?
      
      @cache[mapped_class(instance.class)][instance_key] = instance
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
