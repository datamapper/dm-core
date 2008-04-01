module DataMapper
  module Types
    class Text < DataMapper::Type
      primitive String
      size 65535
      lazy true
    end
  end # module Types  
end # module DataMapper