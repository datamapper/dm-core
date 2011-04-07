module DataMapper
  class Property
    class Boolean < Object
      include PassThroughLoadDump

      primitive ::TrueClass

      TRUE_VALUES  = [ 1, '1', 't', 'T', 'true',  'TRUE'  ].freeze
      FALSE_VALUES = [ 0, '0', 'f', 'F', 'false', 'FALSE' ].freeze
      BOOLEAN_MAP  = Hash[
        TRUE_VALUES.product([ true ]) + FALSE_VALUES.product([ false ]) ].freeze

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
        BOOLEAN_MAP.fetch(value, value)
      end
    end # class Boolean
  end # class Property
end # module DataMapper
