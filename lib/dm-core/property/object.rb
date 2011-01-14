module DataMapper
  class Property
    class Object < Property
      primitive ::Object

      # @api semipublic
      def dump(value)
        return if value.nil?
        [ Marshal.dump(value) ].pack('m')
      end

      # @api semipublic
      def load(value)
        case value
          when ::String
            Marshal.load(value.unpack('m').first)
          when ::Object
            value
          end
      end

      # @api private
      def to_child_key
        self.class
      end
    end
  end
end
