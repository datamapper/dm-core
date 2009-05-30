module DataMapper
  module Conditions
    class InvalidOperation < ArgumentError; end

    class Operation
      # TODO: document
      # @api semipublic
      def self.new(operator, *operands)
        operation_class(operator).new(*operands)
      end

      # TODO: document
      # @api semipublic
      def self.operation_class(operation)
        # TODO: when inheriting, register the class' slug, so that this
        # lookup can be done via a Hash
        operation_classes[operation] ||= AbstractOperation.descendants.detect { |operation_class| operation_class.slug == operation }
      end

      class << self
        private

        def operation_classes
          @operation_classes ||= {}
        end
      end
    end

    class AbstractOperation
      include Enumerable

      # TODO: document
      # @api semipublic
      attr_reader :operands

      # TODO: document
      # @api private
      def self.descendants
        @descendants ||= Set.new
      end

      # TODO: document
      # @api private
      def self.inherited(operation_class)
        descendants << operation_class
      end

      # TODO: document
      # @api semipublic
      def self.slug(slug = nil)
        slug ? @slug = slug : @slug
      end

      # TODO: document
      # @api semipublic
      def each
        @operands.each { |*block_args| yield(*block_args) }
      end

      # TODO: document
      # @api semipublic
      def <<(operand)
        @operands << operand
      end

      # TODO: document
      # @api semipublic
      def ==(other)
        if equal?(other)
          return true
        end

        other_class = other.class

        unless other_class.respond_to?(:slug) && other_class.slug == self.class.slug
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
        @operands.send(operator, other.operands)
      end
    end

    module ConcatOperation
      # TODO: document
      # @api semipublic
      def <<(operand)
        if operand.kind_of?(self.class)
          @operands.concat(operand.operands)
        else
          super
        end
      end
    end

    class AndOperation < AbstractOperation
      include ConcatOperation

      slug :and

      # TODO: document
      # @api semipublic
      def matches?(record)
        @operands.all? { |operand| operand.matches?(record) }
      end
    end

    class OrOperation < AbstractOperation
      include ConcatOperation

      slug :or

      # TODO: document
      # @api semipublic
      def matches?(record)
        @operands.any? { |operand| operand.matches?(record) }
      end
    end

    class NotOperation < AbstractOperation
      slug :not

      # TODO: document
      # @api semipublic
      def matches?(record)
        not @operands.first.matches?(record)
      end

      # TODO: document
      # @api semipublic
      def <<(operand)
        raise ArgumentError, "#{self.class} cannot have more than one operand" if @operands.size > 0
        super
      end

      private

      # TODO: document
      # @api semipublic
      def initialize(*operands)
        raise InvalidOperation, "#{self.class} is a unary operator" if operands.size > 1
        super
      end
    end
  end
end
