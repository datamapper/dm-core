module DataMapper
  module Support

    # AliasingHash works just like a normal hash, except any key in the hash
    # can be aliased to different name.
    #
    # For example:
    # ah = AliasedHash[:color => "brown", :length => 2]
    # ah.alias(:length, :size)
    # ah.size # => 2
    # ah.size = 5
    # ah.size # => 5
    # ah.length # => 5
    module AliasingHash
      
      # Return all defined aliases.
      #
      # ==== Returns
      # Hash:: Hash of aliases with each alias as key and the
      # aliased key as value
      #
      # @public
      def aliases
        return aliasing_hash_aliases
      end
      
      # Return all aliases for a given key
      #
      # ==== Parameters
      # key<Object>::
      #   The key to get alaises for
      #
      # ==== Returns
      # Array:: Aliases for the given key
      #
      # @public
      def key_aliases(key)
        aliasing_hash_aliases.inject([]) { |i, obj| (obj.at(1) == key) ? i << obj.at(0) : i  }
      end
      
      # Access value using a key or alias
      #
      # ==== Parameters
      # key<Object>::
      #   The key to get value for
      #
      # ==== Returns
      # thing:: Value for the given key
      #
      # @public
      def [](key)
        #if key is an alias, return that
        return super(aliasing_hash_aliases[key]) if aliasing_hash_aliases.include?(key)
        
        #otherwise return whatever regular hash would return
        return super
      end
      
      # Assign given value to a key or alias
      #
      # ==== Parameters
      # key<Object>::
      #   The key to get value for
      #
      # ==== Returns
      # thing:: Value for the given key
      #
      # @public
      def []=(key, value)
        #if the key is an alias, lookup the real key
        key = aliasing_hash_aliases[key] if aliasing_hash_aliases.include?(key)
        
        super
      end
      
      # All keys of the hash including aliases
      #
      # ==== Returns
      # Array:: With all keys and aliases
      #
      # @public
      def keys
        super + aliasing_hash_aliases.keys
      end
      
      # Determine if the hash has the given key or alias
      #
      # ==== Parameters
      # key<Object>::
      #   The key or alias to look up
      #
      # ==== Returns
      # TrueClass:: True of False
      #
      # @public
      def has_key?(key)
        #if the key is an alias, lookup the real key
        key = aliasing_hash_aliases[key] if aliasing_hash_aliases.include?(key)
        
        super
      end
      
      # Featch hash value through key or alias
      #
      # ==== Parameters
      # *args::
      #   See Ruby's Hash documentation for arguments
      #
      # ==== Returns
      # TrueClass:: True of False
      #
      # @public
      def fetch(*args)
        #if the key is an alias, lookup the real key
        args[0] = aliasing_hash_aliases[args.at(0)] if aliasing_hash_aliases.include?(args.at(0))
        
        super(*args)
      end
      
      # Assign given value to a key or alias
      #
      # ==== Parameters
      # key<Object>::
      #   The key to get value for
      #
      # === Raises
      # CantAliasAliasesException::
      #   When attempted to alias an alias
      #
      # AliasAlreadyExistsException::
      #   When attempted to create an alias which name already exists as alias
      #
      # KeyAlreadyExistsException::
      #   When attempted to create an alias which name already exists as a key
      #
      # ==== Returns
      # thing:: Value for the given key
      #
      # @public
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
      
      # Local access to the alias map, that assures exiting map is used or a
      # blank hash is returned
      #
      # ==== Returns
      # Hash:: alias map or empty hash
      #
      def aliasing_hash_aliases
        @aliases ||= {}
      end
    end # module AliasingHash
    
  end # module Support
end # module DataMapper

class AliasingHash < Hash #:nodoc:
  include DataMapper::Support::AliasingHash
end