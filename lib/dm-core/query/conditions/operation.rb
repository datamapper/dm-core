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
        extend Equalizer

        equalize :slug, :sorted_operands

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

        # Return the comparison class slug
        #
        # @return [Symbol]
        #   the comparison class slug
        #
        # @api private
        def slug
          self.class.slug
        end

        # TODO: document
        # @api semipublic
        def each
          @operands.each { |*block_args| yield(*block_args) }
        end

        # TODO: document
        # @api semipublic
        def valid?
          operands.any? && operands.all? do |operand|
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
        def inspect
          "#<#{self.class} @operands=#{@operands.inspect}>"
        end

        # Return a list of operands in predictable order
        #
        # @return [Array<AbstractOperation>]
        #   list of operands sorted in deterministic order
        #
        # @api private
        def sorted_operands
          @operands.sort_by { |operand| operand.hash }
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

      class NullOperation < AbstractOperation
        undef_method :<<

        slug :null

        # Match the record
        #
        # @param [Resource] record
        #   the resource to match
        #
        # @return [true]
        #   every record matches
        #
        # @api semipublic
        def matches?(record)
          true
        end

        # Test validity of the operation
        #
        # @return [true]
        #   always valid
        #
        # @api semipublic
        def valid?
          true
        end

        # Treat the operation the same as nil
        #
        # @return [true]
        #   should be treated as nil
        #
        # @api semipublic
        def nil?
          true
        end

        # Inspecting the operation should return the same as nil
        #
        # @return [String]
        #   return the string 'nil'
        #
        # @api semipublic
        def inspect
          'nil'
        end
      end
    end # module Conditions
  end # class Query
end # module DataMapper
