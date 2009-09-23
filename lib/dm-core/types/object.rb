module DataMapper
  module Types
    class Object < Type
      primitive String
      length    65535
      lazy      true

      # TODO: document
      # @api private
      def self.typecast(value, property)
        value
      end

      # TODO: document
      # @api private
      def self.dump(value, property)
        [ Marshal.dump(value) ].pack('m')
      end

      # TODO: document
      # @api private
      def self.load(value, property)
        Marshal.load(value.unpack('m').first) unless value.nil?
      end
    end
  end
end
