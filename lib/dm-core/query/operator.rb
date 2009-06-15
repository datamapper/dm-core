# TODO: rename this DM::Symbol::Operator

# TODO: add a method to convert it into a DM::Query::AbstractComparison object, eg:
#   operator.comparison_for(repository, model)

# TODO: rename #target to #property_name

module DataMapper
  class Query
    class Operator
      include Extlib::Assertions

      # TODO: document
      # @api private
      attr_reader :target

      # TODO: document
      # @api private
      attr_reader :operator

      # TODO: document
      # @api private
      def ==(other)
        if equal?(other)
          return true
        end

        unless other.respond_to?(:target)
          return false
        end

        unless other.respond_to?(:operator)
          return false
        end

        cmp?(other, :==)
      end

      # TODO: document
      # @api private
      def eql?(other)
        if equal?(other)
          return true
        end

        unless instance_of?(other.class)
          return false
        end

        cmp?(other, :eql?)
      end

      # TODO: document
      # @api private
      def hash
        @target.hash
      end

      # TODO: document
      # @api private
      def inspect
        "#<#{self.class.name} @target=#{target.inspect} @operator=#{operator.inspect}>"
      end

      private

      # TODO: document
      # @api private
      def initialize(target, operator)
        assert_kind_of 'operator', operator, Symbol

        @target   = target
        @operator = operator
      end

      # TODO: document
      # @api private
      def cmp?(other, operator)
        target.send(operator, other.target) &&
        self.operator.send(operator, other.operator)
      end
    end # class Operator
  end # class Query
end # module DataMapper
