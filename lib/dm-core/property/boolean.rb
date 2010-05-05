module DataMapper
  class Property
    class Boolean < Object
      include PassThroughLoadDump

      primitive ::TrueClass

      def primitive?(value)
        value == true || value == false
      end

      # Typecast a value to a true or false
      #
      # @param [Integer, #to_str] value
      #   value to typecast
      #
      # @return [Boolean]
      #   true or false constructed from value
      #
      # @api private
      def typecast_to_primitive(value)
        if value.kind_of?(::Integer)
          return true  if value == 1
          return false if value == 0
        elsif value.respond_to?(:to_str)
          string_value = value.to_str.downcase
          return true  if %w[ true  1 t ].include?(string_value)
          return false if %w[ false 0 f ].include?(string_value)
        end

        value
      end
    end # class Boolean
  end # class Property
end # module DataMapper
