module DataMapper
  module Support
    
    module AliasingHash
      
      #return all defined aliases in :alias => :key format
      attr_reader :aliases
      def aliases(key = nil)
        return aliasing_hash_aliases
      end
      
      #return all aliases for a key as an array
      attr_reader :key_aliases
      def key_aliases(key)
        aliasing_hash_aliases.inject([]) { |i, obj| (obj[1] == key) ? i << obj[0] : i  }
      end
      
      def [](key)
        #if key is an alias, return that
        return super(aliasing_hash_aliases[key]) if aliasing_hash_aliases.include?(key)
        
        #otherwise return whatever regular hash would return
        return super
      end
      
      def []=(key, value)
        #if the key is an alias, assign the value
        return super(aliasing_hash_aliases[key], value) if aliasing_hash_aliases.include?(key)
        
        #otherwise do whatever normal hash would do
        return super
      end
      
      def alias!(key, key_alias)
        #aliasing aliases is not allowed
        raise CantAliasAliasesException if aliases.include?(key)
        
        #make sure there are no keys or aliases with the requested new aliases already
        raise AliasAlreadyExistsException if aliasing_hash_aliases.include?(key_alias)
        raise KeyAlreadyExistsException if self.include?(key_alias)
        
        #assign the alias
        aliasing_hash_aliases[key_alias] = key
        
        return self
      end

      class CantAliasAliasesException < Exception; end
      class AliasAlreadyExistsException < Exception; end
      class KeyAlreadyExistsException < Exception; end
      
      private
      def aliasing_hash_aliases
        return @aliases ||= {}
      end
    end
    
  end
end

class AliasingHash < Hash
  include DataMapper::Support::AliasingHash
end