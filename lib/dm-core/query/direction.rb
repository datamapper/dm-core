module DataMapper
  class Query
    class Direction
      include Extlib::Assertions

      attr_reader :property
      attr_reader :direction

      def ==(other)
        return true if equal?(other)
        return false unless other.respond_to?(:property) &&
                            other.respond_to?(:direction)

        cmp?(other, :==)
      end

      def eql?(other)
        return true if equal?(other)
        return false unless self.class.equal?(other.class)

        cmp?(other, :eql?)
      end

      def hash
        property.hash + direction.hash
      end

      def reverse!
        @direction = @direction == :asc ? :desc : :asc
        self
      end

      private

      def initialize(property, direction = :asc)
        assert_kind_of 'property',  property,  Property
        assert_kind_of 'direction', direction, Symbol

        @property  = property
        @direction = direction
      end

      def cmp?(other, operator)
        property.send(operator, other.property) &&
        direction.send(operator, other.direction)
      end
    end # class Direction
  end # class Query
end # module DataMapper
