module DataMapper
  class Query
    module Conditions
      class InvalidOperation < ArgumentError; end

      class Operation
        # TODO: document
        # @api semipublic
        def self.new(slug, *operands)
          if klass = operation_class(slug)
            klass.new(*operands)
          else
            raise "No Operation class for `#{slug.inspect}' has been defined"
          end
        end

        # TODO: document
        # @api semipublic
        def self.operation_class(slug)
          operation_classes[slug] ||= AbstractOperation.descendants.detect { |operation_class| operation_class.slug == slug }
        end

        # TODO: document
        # @api private
        def self.slugs
          @slugs ||= AbstractOperation.descendants.map { |operation_class| operation_class.slug }
        end

        class << self
          private

          # TODO: document
          # @api private
          def operation_classes
            @operation_classes ||= {}
          end
        end
      end # class Operation

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
        def valid?
          @valid
        end

        # TODO: document
        # @api semipublic
        def <<(operand)
          @operands << operand
          @valid = operand.valid? if @valid && operand.respond_to?(:valid?)
          self
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

          unless instance_of?(other.class)
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
          @valid    = true
        end

        # TODO: document
        # @api semipublic
        def initialize_copy(*)
          @operands = @operands.map { |operand| operand.dup }
        end

        # TODO: document
        # @api private
        def cmp?(other, operator)
          @operands.send(operator, other.operands)
        end
      end # class AbstractOperation

      module FlattenOperation
        # TODO: document
        # @api semipublic
        def <<(operand)
          if operand.kind_of?(self.class)
            @operands.concat(operand.operands)
          else
            super
          end
        end
      end # module FlattenOperation

      class AndOperation < AbstractOperation
        include FlattenOperation

        slug :and

        # TODO: document
        # @api semipublic
        def matches?(record)
          @operands.all? { |operand| operand.matches?(record) }
        end
      end # class AndOperation

      class OrOperation < AbstractOperation
        include FlattenOperation

        slug :or

        # TODO: document
        # @api semipublic
        def matches?(record)
          @operands.any? { |operand| operand.matches?(record) }
        end
      end # class OrOperation

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
      end # class NotOperation
    end # module Conditions
  end # class Query
end # module DataMapper
