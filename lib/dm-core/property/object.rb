module DataMapper
  class Property
    class Object < Property
      primitive ::Object

      # @api semipublic
      def dump(value)
        return value if value.nil?

        if @type
          @type.dump(value, self)
        else
          [ Marshal.dump(value) ].pack('m')
        end
      end

      # @api semipublic
      def load(value)
        if @type
          return @type.load(value, self)
        end

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
