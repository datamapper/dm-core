module DataMapper
  module Types
    class HugeInteger < DataMapper::Property::String
      def self.load(value, property)
        value.to_i unless value.nil?
      end

      def self.dump(value, property)
        value.to_s unless value.nil?
      end

      def self.typecast(value, property)
        load(value, property)
      end
    end
  end
end
