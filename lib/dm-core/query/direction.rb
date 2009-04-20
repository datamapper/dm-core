module DataMapper
  class Query
    class Direction
      include Extlib::Assertions

      # TODO: document
      # @api private
      attr_reader :property

      # TODO: document
      # @api private
      attr_reader :direction

      # TODO: document
      # @api private
      def reverse!
        @direction = @direction == :asc ? :desc : :asc
        self
      end

      # TODO: document
      # @api private
      def ==(other)
        return true if equal?(other)
        return false unless other.respond_to?(:property) &&
                            other.respond_to?(:direction)

        cmp?(other, :==)
      end

      # TODO: document
      # @api private
      def eql?(other)
        return true if equal?(other)
        return false unless self.class.equal?(other.class)

        cmp?(other, :eql?)
      end

      # TODO: document
      # @api private
      def hash
        property.hash + direction.hash
      end

      # TODO: document
      # @api private
      def inspect
        "#<#{self.class.name} @property=#{property.inspect} @direction=#{direction.inspect}>"
      end

      private

      # TODO: document
      # @api private
      def initialize(property, direction = :asc)
        assert_kind_of 'property',  property,  Property
        assert_kind_of 'direction', direction, Symbol

        @property  = property
        @direction = direction
      end

      # TODO: document
      # @api private
      def cmp?(other, operator)
        property.send(operator, other.property) &&
        direction.send(operator, other.direction)
      end
    end # class Direction
  end # class Query
end # module DataMapper
