module DataMapper
  class Query
    class Sort
      attr_reader :value

      # TODO: document
      # @api private
      def <=>(other)
        other_value = other.value

        cmp = case
          when @value.nil? && other_value.nil? then  0
          when @value.nil?                     then  1
          when other_value.nil?                then -1
          else @value <=> other_value
        end

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
