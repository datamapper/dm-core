module DataMapper
  module Types
    class Object < Type
      primitive String
      size 65535
      lazy true

      # TODO: document
      # @api private
      def self.typecast(value, property)
        value
      end

      # TODO: document
      # @api private
      def self.dump(value, property)
        Base64.encode64(Marshal.dump(value))
      end

      # TODO: document
      # @api private
      def self.load(value, property)
        value.nil? ? nil : Marshal.load(Base64.decode64(value))
      end
    end
  end
end
