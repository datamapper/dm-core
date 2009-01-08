module DataMapper
  class Query
    class Direction
      include Extlib::Assertions

      attr_reader :property, :direction

      def ==(other)
        return true if super
        hash == other.hash
      end

      alias eql? ==

      def hash
        @property.hash + @direction.hash
      end

      def reverse
        self.class.new(@property, @direction == :asc ? :desc : :asc)
      end

      def inspect
        "#<#{self.class.name} #{@property.inspect} #{@direction}>"
      end

      private

      def initialize(property, direction = :asc)
        assert_kind_of 'property',  property,  Property
        assert_kind_of 'direction', direction, Symbol

        @property  = property
        @direction = direction
      end
    end # class Direction
  end # class Query
end # module DataMapper
