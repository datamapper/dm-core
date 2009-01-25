module DataMapper
  class Query
    class Operator
      include Extlib::Assertions

      attr_reader :target
      attr_reader :operator

      def ==(other)
        return true if equal?(other)
        return false unless other.respond_to?(:target) && other.respond_to?(:operator)

        target == other.target && operator == other.operator
      end

      def eql?(other)
        return true if equal?(other)
        return false unless self.class.equal?(other.class)

        target.eql?(other.target) && operator.eql?(other.operator)
      end

      private

      def initialize(target, operator)
        assert_kind_of 'operator', operator, Symbol

        @target   = target
        @operator = operator
      end
    end # class Operator
  end # class Query
end # module DataMapper
