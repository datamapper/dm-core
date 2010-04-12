require 'dm-core/type'

module DataMapper
  module Types
    class Decimal < Type
      primitive BigDecimal
    end # class Decimal
  end # module Types
end # module DataMapper
