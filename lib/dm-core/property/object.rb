module DataMapper
  class Property
    class Object < Property
      load_as ::Object
      dump_as ::Object

      # @api semipublic
      def dump(value)
        instance_of?(Object) ? marshal(value) : value
      end

      # @api semipublic
      def load(value)
        typecast(instance_of?(Object) ? unmarshal(value) : value)
      end

      # @api semipublic
      def marshal(value)
        [ Marshal.dump(value) ].pack('m') unless value.nil?
      end

      # @api semipublic
      def unmarshal(value)
        Marshal.load(value.unpack('m').first) unless value.nil?
      end

      # @api private
      def to_child_key
        self.class
      end
    end
  end
end
