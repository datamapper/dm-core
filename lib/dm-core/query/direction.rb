module DataMapper
  class Query
    class Direction < Operator
      extend Deprecate

      deprecate :property,  :target
      deprecate :direction, :operator

      # TODO: document
      # @api private
      def reverse!
        @operator = @operator == :asc ? :desc : :asc
        self
      end

      # TODO: document
      # @api private
      def get(resource)
        Sort.new(target.get(resource), @operator == :asc)
      end

      private

      # TODO: document
      # @api private
      def initialize(target, operator = :asc)
        super
      end
    end # class Direction
  end # class Query
end # module DataMapper
