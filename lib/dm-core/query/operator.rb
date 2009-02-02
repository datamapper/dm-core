module DataMapper
  class Query
    class Operator
      include Extlib::Assertions

      attr_reader :target
      attr_reader :operator

      def ==(other)
        return true if equal?(other)
        return false unless other.respond_to?(:target) && other.respond_to?(:operator)

        cmp?(other, :==)
      end

      def eql?(other)
        return true if equal?(other)
        return false unless self.class.equal?(other.class)

        cmp?(other, :eql?)
      end

      private

      def initialize(target, operator)
        assert_kind_of 'operator', operator, Symbol

        @target   = target
        @operator = operator
      end

      def cmp?(other, operator)
        target.send(operator, other.target) && self.operator.send(operator, other.operator)
      end
    end # class Operator
  end # class Query
end # module DataMapper
