module DataMapper

  # Tracks objects to help ensure that each object gets loaded only once.
  # See: http://www.martinfowler.com/eaaCatalog/identityMap.html
  class IdentityMap < Hash
    extend Deprecate

    deprecate :get, :[]
    deprecate :set, :[]=

  end # class IdentityMap
end # module DataMapper
