module DataMapper
  class Property
    class Numeric < Object
      include PassThroughLoadDump
      include Typecast::Numeric

      accept_options :precision, :scale, :min, :max
      attr_reader :precision, :scale, :min, :max

      DEFAULT_NUMERIC_MIN = 0
      DEFAULT_NUMERIC_MAX = 2**31-1

      protected

      def initialize(model, name, options = {})
        super

        if @primitive == BigDecimal || @primitive == ::Float
          @precision = @options.fetch(:precision)
          @scale     = @options.fetch(:scale)

          unless @precision > 0
            raise ArgumentError, "precision must be greater than 0, but was #{@precision.inspect}"
          end
        end

        if @options.key?(:min) || @options.key?(:max)
          @min = @options.fetch(:min, self.class::DEFAULT_NUMERIC_MIN)
          @max = @options.fetch(:max, self.class::DEFAULT_NUMERIC_MAX)

          if @max < DEFAULT_NUMERIC_MIN && !@options.key?(:min)
            raise ArgumentError, "min should be specified when the max is less than #{DEFAULT_NUMERIC_MIN}"
          elsif @max < @min
            raise ArgumentError, "max must be less than the min, but was #{@max} while the min was #{@min}"
          end
        end
      end
    end # class Numeric
  end # class Property
end # module DataMapper
