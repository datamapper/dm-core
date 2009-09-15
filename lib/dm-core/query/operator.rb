# TODO: rename this DM::Symbol::Operator

# TODO: add a method to convert it into a DM::Query::AbstractComparison object, eg:
#   operator.comparison_for(repository, model)

# TODO: rename #target to #property_name

module DataMapper
  class Query
    class Operator
      include Extlib::Assertions
      extend Equalizer

      equalize :target, :operator

      # TODO: document
      # @api private
      attr_reader :target

      # TODO: document
      # @api private
      attr_reader :operator

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
    end # class Operator
  end # class Query
end # module DataMapper
