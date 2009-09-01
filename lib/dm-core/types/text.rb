module DataMapper
  module Types
    class Text < Type
      primitive String
      length    65535
      lazy      true
    end # class Text
  end # module Types
end # module DataMapper
