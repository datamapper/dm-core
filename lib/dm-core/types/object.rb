module DataMapper
  module Types
    class Object < Type
      primitive Text

      # @api private
      def self.typecast(value, property)
        value
      end

      # @api private
      def self.dump(value, property)
        [ Marshal.dump(value) ].pack('m') unless value.nil?
      end

      # @api private
      def self.load(value, property)
        Marshal.load(value.unpack('m').first) unless value.nil?
      end
    end
  end
end
