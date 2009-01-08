module DataMapper
  class Query
    class Operator
      include Extlib::Assertions

      attr_reader :target, :operator

      def to_sym
        @property_name
      end

      def ==(other)
        return true if super
        return false unless other.kind_of?(self.class)
        @operator == other.operator && @target == other.target
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
