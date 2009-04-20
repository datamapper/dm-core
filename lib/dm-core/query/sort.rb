module DataMapper
  class Query
    class Sort
      attr_reader :value

      # TODO: document
      # @api private
      def <=>(other)
        cmp = @value <=> other.value
        cmp *= -1 unless @ascending
        cmp
      end

      private

      # TODO: document
      # @api private
      def initialize(value, ascending = true)
        @value     = value
        @ascending = ascending
      end
    end # class Sort
  end # class Query
end # module DataMapper
