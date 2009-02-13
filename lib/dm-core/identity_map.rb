module DataMapper

  # Tracks objects to help ensure that each object gets loaded only once.
  # See: http://www.martinfowler.com/eaaCatalog/identityMap.html
  class IdentityMap < Hash

    ##
    # Get a resource from the IdentityMap
    #
    # @param [Enumerable] key
    #   the Resource key
    #
    # @return [Resource,NilClass]
    #   the Resource with the key, or nil if not found
    #
    # @api public
    def get(key)
      warn "#{self.class}#get is deprecated, use #{self.class}#[] instead"
      self[key]
    end

    ##
    # Add a resource to the IdentityMap
    #
    # @param [Enumerable] key
    #   the Resource key
    # @param [Resource] resource
    #   the Resource
    #
    # @return [Resource]
    #   the Resource
    #
    # @api public
    def set(key, resource)
      warn "#{self.class}#set is deprecated, use #{self.class}#[]= instead"
      self[key] = resource
    end
  end # class IdentityMap
end # module DataMapper
