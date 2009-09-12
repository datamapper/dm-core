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
          operands.all? do |operand|
            if operand.respond_to?(:valid?)
              operand.valid?
            else
              true
            end
          end
        end

        # TODO: document
        # @api semipublic
        def <<(operand)
          @operands << operand
          self
        end

        # TODO: document
        # @api semipublic
        def hash
          @operands.sort_by { |operand| operand.hash }.hash
        end

        # TODO: document
        # @api semipublic
        def ==(other)
          return true if equal?(other)
          other.class.respond_to?(:slug)      &&
          other.class.slug == self.class.slug &&
          other.respond_to?(:operands)        &&
          cmp?(other, :==)
        end

        # TODO: document
        # @api semipublic
        def eql?(other)
          return true if equal?(other)
          instance_of?(other.class) && cmp?(other, :eql?)
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
        # @api semipublic
        def initialize_copy(*)
          @operands = @operands.map { |operand| operand.dup }
        end

        # TODO: document
        # @api private
        def cmp?(other, operator)
          @operands.sort_by { |operand| operand.hash }.send(operator, other.operands.sort_by { |operand| operand.hash })
        end
      end # class AbstractOperation

      module FlattenOperation
        # TODO: document
        # @api semipublic
        def <<(operand)
          if operand.kind_of?(self.class)
            @operands.concat(operand.operands)
            self
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
