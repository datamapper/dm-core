module DataMapper
  class Property
    class Decimal < Numeric
      load_as         BigDecimal
      coercion_method :to_decimal

      DEFAULT_PRECISION = 10
      DEFAULT_SCALE     = 0

      precision(DEFAULT_PRECISION)
      scale(DEFAULT_SCALE)

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

    end # class Decimal
  end # class Property
end # module DataMapper
