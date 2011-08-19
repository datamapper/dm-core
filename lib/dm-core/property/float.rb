module DataMapper
  class Property
    class Float < Numeric
      primitive ::Float

      DEFAULT_PRECISION = 10
      DEFAULT_SCALE     = nil

      precision(DEFAULT_PRECISION)
      scale(DEFAULT_SCALE)

      protected

      # Typecast a value to a Float
      #
      # @param [#to_str, #to_f] value
      #   value to typecast
      #
      # @return [Float]
      #   Float constructed from value
      #
      # @api private
      def typecast_to_primitive(value)
        typecast_to_numeric(value, :to_f)
      end
    end # class Float
  end # class Property
end # module DataMapper
