module DataMapper
  class Property
    class Binary < String
      include PassThroughLoadDump
    end # class Binary
  end # class Property
end # module DataMapper
