module DataMapper
  class Property
    class HugeInteger < DataMapper::Property::String
      def load(value)
        value.to_i unless value.nil?
      end

      def dump(value)
        value.to_s unless value.nil?
      end

      def typecast(value)
        load(value)
      end
    end
  end
end
