module DataMapper
  class Property
    class Boolean < Object
      include PassThroughLoadDump

      primitive ::TrueClass

      TRUE_VALUES  = [ 1, '1', 't', 'T', 'true',  'TRUE'  ].to_set.freeze
      FALSE_VALUES = [ 0, '0', 'f', 'F', 'false', 'FALSE' ].to_set.freeze

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
        if TRUE_VALUES.include?(value)
          true
        elsif FALSE_VALUES.include?(value)
          false
        else
          value
        end
      end
    end # class Boolean
  end # class Property
end # module DataMapper
