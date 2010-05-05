module DataMapper
  class Property
    class Decimal < Numeric
      primitive BigDecimal

      DEFAULT_SCALE = 0

      protected

      def initialize(model, name, options = {}, type = nil)
        super

        unless @scale.nil?
          unless @scale >= 0
            raise ArgumentError, "scale must be equal to or greater than 0, but was #{@scale.inspect}"
          end

          unless @precision >= @scale
            raise ArgumentError, "precision must be equal to or greater than scale, but was #{@precision.inspect} and scale was #{scale_inspect}"
          end
        end
      end

      # Typecast a value to a BigDecimal
      #
      # @param [#to_str, #to_d, Integer] value
      #   value to typecast
      #
      # @return [BigDecimal]
      #   BigDecimal constructed from value
      #
      # @api private
      def typecast_to_primitive(value)
        if value.kind_of?(::Integer)
          # TODO: remove this case when Integer#to_d added by extlib
          value.to_s.to_d
        else
          typecast_to_numeric(value, :to_d)
        end
      end
    end # class Decimal
  end # class Property
end # module DataMapper
