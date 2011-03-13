module DataMapper
  class Property
    class Decimal < Numeric
      primitive BigDecimal

      DEFAULT_SCALE = 0

      protected

      def initialize(model, name, options = {})
        super

        [ :scale, :precision ].each do |key|
          unless options.key?(key)
            warn "options[#{key.inspect}] should be set for #{self.class}, defaulting to #{send(key).inspect}"
          end
        end

        unless @scale >= 0
          raise ArgumentError, "scale must be equal to or greater than 0, but was #{@scale.inspect}"
        end

        unless @precision >= @scale
          raise ArgumentError, "precision must be equal to or greater than scale, but was #{@precision.inspect} and scale was #{@scale.inspect}"
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
          value.to_s.to_d
        else
          typecast_to_numeric(value, :to_d)
        end
      end
    end # class Decimal
  end # class Property
end # module DataMapper
