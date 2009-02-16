module DataMapper
  module Conditions
    class InvalidOperation < Exception; end

    class BooleanOperation
      def self.new(operator, *operands)
        operation_class(operator).new(*operands)
      end

      def self.operation_class(operation)
        AbstractOperation.subclasses.detect { |c| c.slug == operation }
      end
    end

    class AbstractOperation
      attr_reader :operands

      def self.subclasses
        @subclasses ||= Set.new
      end

      def self.inherited(subclass)
        subclasses << subclass
      end

      def self.slug(slug = nil)
        slug ? @slug = slug : @slug
      end

      def <<(operand)
        operands << operand
      end

      def ==(other)
        if equal?(other)
          return true
        end

        unless other.class.respond_to?(:slug) && other.class.slug == self.class.slug
          return false
        end

        unless other.respond_to?(:operands)
          return false
        end

        cmp?(other, :==)
      end

      def eql?(other)
        if equal?(other)
          return true
        end

        unless self.class.equal?(other.class)
          return false
        end

        cmp?(other, :eql?)
      end

      def inspect
        "#<#{self.class} @operands=#{@operands.inspect}>"
      end

      private

      def initialize(*operands)
        @operands = operands
      end

      def cmp?(other, operator)
        operands.send(operator, other.operands)
      end
    end

    class AndOperation < AbstractOperation
      slug :and

      def matches?(record)
        @operands.all? { |o| o.matches?(record) }
      end
    end

    class OrOperation < AbstractOperation
      slug :or

      def matches?(record)
        @operands.any? { |o| o.matches?(record) }
      end
    end

    class NotOperation < AbstractOperation
      slug :not

      def initialize(*operands)
        super
        raise InvalidOperation, 'Not is a unary operator' if @operands.size > 1
        @operand = @operands.first
      end

      def matches?(record)
        not @operand.matches?(record)
      end
    end
  end
end
