module DataMapper
  class Property
    class Object < Property
      load_as ::Object

      # @api semipublic
      def dump(value)
        if self.class == Object
          marshal(value)
        else
          value
        end
      end

      # @api semipublic
      def load(value)
        if self.class == Object
          unmarshal(value)
        else
          typecast(value)
        end
      end

      # @api semipublic
      def marshal(value)
        return if value.nil?
        [ Marshal.dump(value) ].pack('m')
      end

      # @api semipublic
      def unmarshal(value)
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
