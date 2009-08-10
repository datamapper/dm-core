module DataMapper
  module Types
    class Serial < Type
      primitive Integer
      serial    true
      min       1
    end # class Text
  end # module Types
end # module DataMapper
