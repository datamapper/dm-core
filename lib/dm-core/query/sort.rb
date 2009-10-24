# TODO: add #reverse and #reverse! methods

module DataMapper
  class Query
    class Sort
      # @api semipublic
      attr_reader :value

      # @api semipublic
      def direction
        @ascending ? :ascending : :descending
      end

      # @api private
      def <=>(other)
        other_value = other.value

        cmp = case
          when @value.nil? && other_value.nil?
            0
          when @value.nil?
            1
          when other_value.nil?
            -1
          else
            @value <=> other_value
        end

        @ascending ? cmp : cmp * -1
      end

      private

      # @api private
      def initialize(value, ascending = true)
        @value     = value
        @ascending = ascending
      end
    end # class Sort
  end # class Query
end # module DataMapper
