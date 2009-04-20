module DataMapper
  module Conditions
    class InvalidOperation < Exception; end

    class BooleanOperation
      # TODO: document
      # @api semipublic
      def self.new(operator, *operands)
        operation_class(operator).new(*operands)
      end

      # TODO: document
      # @api semipublic
      def self.operation_class(operation)
        AbstractOperation.subclasses.detect { |c| c.slug == operation }
      end
    end

    class AbstractOperation

      # TODO: document
      # @api semipublic
      attr_reader :operands

      # TODO: document
      # @api private
      def self.subclasses
        @subclasses ||= Set.new
      end

      # TODO: document
      # @api private
      def self.inherited(subclass)
        subclasses << subclass
      end

      # TODO: document
      # @api semipublic
      def self.slug(slug = nil)
        slug ? @slug = slug : @slug
      end

      # TODO: document
      # @api semipublic
      def <<(operand)
        operands << operand
      end

      # TODO: document
      # @api semipublic
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

      # TODO: document
      # @api semipublic
      def eql?(other)
        if equal?(other)
          return true
        end

        unless self.class.equal?(other.class)
          return false
        end

        cmp?(other, :eql?)
      end

      # TODO: document
      # @api semipublic
      def inspect
        "#<#{self.class} @operands=#{@operands.inspect}>"
      end

      private

      # TODO: document
      # @api semipublic
      def initialize(*operands)
        @operands = operands
      end

      # TODO: document
      # @api private
      def cmp?(other, operator)
        operands.send(operator, other.operands)
      end
    end

    class AndOperation < AbstractOperation
      slug :and

      # TODO: document
      # @api semipublic
      def matches?(record)
        @operands.all? { |o| o.matches?(record) }
      end

      # TODO: document
      # @api semipublic
      def <<(operand)
        if operand.kind_of?(self.class)
          operands.concat(operand.operands)
        else
          super
        end
      end
    end

    class OrOperation < AbstractOperation
      slug :or

      # TODO: document
      # @api semipublic
      def matches?(record)
        @operands.any? { |o| o.matches?(record) }
      end

      # TODO: document
      # @api semipublic
      def <<(operand)
        if operand.kind_of?(self.class)
          operands.concat(operand.operands)
        else
          super
        end
      end
    end

    class NotOperation < AbstractOperation
      slug :not

      # TODO: document
      # @api semipublic
      def matches?(record)
        not @operand.matches?(record)
      end

      # TODO: document
      # @api semipublic
      def <<(operand)
        raise ArgumentError, "#{self.class} cannot have more than one operand" if operands.size > 0
        super
      end

      private

      # TODO: document
      # @api semipublic
      def initialize(*operands)
        super
        raise InvalidOperation, 'Not is a unary operator' if @operands.size > 1
        @operand = @operands.first
      end
    end
  end
end
