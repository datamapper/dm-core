module DataMapper
  class Query
    module Conditions
      class Operation
        # Factory method to initialize an operation
        #
        # @example
        #   operation = Operation.new(:and, comparison)
        #
        # @param [Symbol] slug
        #   the identifier for the operation class
        # @param [Array] *operands
        #   the operands to initialize the operation with
        #
        # @return [AbstractOperation]
        #   the operation matching the slug
        #
        # @api semipublic
        def self.new(slug, *operands)
          if klass = operation_class(slug)
            klass.new(*operands)
          else
            raise ArgumentError, "No Operation class for #{slug.inspect} has been defined"
          end
        end

        # Return an Array of all the slugs for the operation classes
        #
        # @return [Array]
        #   the slugs of all the operation classes
        #
        # @api private
        def self.slugs
          AbstractOperation.descendants.map { |operation_class| operation_class.slug }
        end

        class << self
          private

          # Returns a Hash mapping the slugs to each class
          #
          # @return [Hash]
          #   Hash mapping the slug to the class
          #
          # @api private
          def operation_classes
            @operation_classes ||= {}
          end

          # Lookup the operation class based on the slug
          #
          # @example
          #   operation_class = Operation.operation_class(:and)
          #
          # @param [Symbol] slug
          #   the identifier for the operation class
          #
          # @return [Class]
          #   the operation class
          #
          # @api private
          def operation_class(slug)
            operation_classes[slug] ||= AbstractOperation.descendants.detect { |operation_class| operation_class.slug == slug }
          end
        end
      end # class Operation

      class AbstractOperation
        include Extlib::Assertions
        include Enumerable
        extend Equalizer

        equalize :slug, :sorted_operands

        # Returns the parent operation
        #
        # @return [AbstractOperation]
        #   the parent operation
        #
        # @api semipublic
        attr_accessor :parent

        # Returns the child operations and comparisons
        #
        # @return [Set<AbstractOperation, AbstractComparison, Array>]
        #   the set of operations and comparisons
        #
        # @api semipublic
        attr_reader :operands

        alias children operands

        # Returns the classes that inherit from AbstractComparison
        #
        # @return [Set]
        #   the descendant classes
        #
        # @api private
        def self.descendants
          @descendants ||= Set.new
        end

        # Hook executed when inheriting from AbstractComparison
        #
        # @return [undefined]
        #
        # @api private
        def self.inherited(operation_class)
          descendants << operation_class
        end

        # Get and set the slug for the operation class
        #
        # @param [Symbol] slug
        #   optionally set the slug for the operation class
        #
        # @return [Symbol]
        #   the slug for the operation class
        #
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

        # Iterate through each operand in the operation
        #
        # @yield [operand]
        #   yields to each operand
        #
        # @yieldparam [AbstractOperation, AbstractComparison, Array] operand
        #   each operand
        #
        # @return [self]
        #   returns the operation
        #
        # @api semipublic
        def each
          @operands.each { |op| yield op }
          self
        end

        # Test if the operation is valid
        #
        # @return [Boolean]
        #   true if the operation is valid, false if not
        #
        # @api semipublic
        def valid?
          any? && all? { |op| valid_operand?(op) }
        end

        # Add an operand to the operation
        #
        # @param [AbstractOperation, AbstractComparison, Array] operand
        #   the operand to add
        #
        # @return [self]
        #   the operation
        #
        # @api semipublic
        def <<(operand)
          assert_valid_operand_type(operand)
          @operands << relate_operand(operand)
          self
        end

        # Add operands to the operation
        #
        # @param [#each] operands
        #   the operands to add
        #
        # @return [self]
        #   the operation
        #
        # @api semipublic
        def merge(operands)
          operands.each { |op| self << op }
          self
        end

        # Return the union with another operand
        #
        # @param [AbstractOperation] other
        #   the operand to union with
        #
        # @return [OrOperation]
        #   the union of the operation and operand
        #
        # @api semipublic
        def union(other)
          Operation.new(:or, dup, other.dup).minimize
        end

        alias | union
        alias + union

        # Return the intersection of the operation and another operand
        #
        # @param [AbstractOperation] other
        #   the operand to intersect with
        #
        # @return [AndOperation]
        #   the intersection of the operation and operand
        #
        # @api semipublic
        def intersection(other)
          Operation.new(:and, dup, other.dup).minimize
        end

        alias & intersection

        # Return the difference of the operation and another operand
        #
        # @param [AbstractOperation] other
        #   the operand to not match
        #
        # @return [AndOperation]
        #   the intersection of the operation and operand
        #
        # @api semipublic
        def difference(other)
          Operation.new(:and, dup, Operation.new(:not, other.dup)).minimize
        end

        alias - difference

        # Minimize the operation
        #
        # @return [self]
        #   the minimized operation
        #
        # @api semipublic
        def minimize
          self
        end

        # Clear the operands
        #
        # @return [self]
        #   the operation
        #
        # @api semipublic
        def clear
          @operands.clear
          self
        end

        # Return the string representation of the operation
        #
        # @return [String]
        #   the string representation of the operation
        #
        # @api semipublic
        def to_s
          empty? ? '' : "(#{sort_by { |op| op.to_s }.map { |op| op.to_s }.join(" #{slug.to_s.upcase} ")})"
        end

        # Test if the operation is negated
        #
        # Defaults to return false.
        #
        # @return [Boolean]
        #   true if the operation is negated, false if not
        #
        # @api private
        def negated?
          parent = self.parent
          parent ? parent.negated? : false
        end

        # Return a list of operands in predictable order
        #
        # @return [Array<AbstractOperation, AbstractComparison, Array>]
        #   list of operands sorted in deterministic order
        #
        # @api private
        def sorted_operands
          sort_by { |op| op.hash }
        end

        private

        # Initialize an operation
        #
        # @param [Array<AbstractOperation, AbstractComparison, Array>] *operands
        #   the operands to include in the operation
        #
        # @return [AbstractOperation]
        #   the operation
        #
        # @api semipublic
        def initialize(*operands)
          @operands = Set.new
          merge(operands)
        end

        # Copy an operation
        #
        # @param [AbstractOperation] original
        #   the original operation
        #
        # @return [undefined]
        #
        # @api semipublic
        def initialize_copy(*)
          @operands = map { |op| op.dup }.to_set
        end

        # Minimize the operands recursively
        #
        # @return [undefined]
        #
        # @api private
        def minimize_operands
          # FIXME: why does Set#map! not work here?
          @operands = map do |op|
            relate_operand(op.respond_to?(:minimize) ? op.minimize : op)
          end.to_set
        end

        # Prune empty operands recursively
        #
        # @return [undefined]
        #
        # @api private
        def prune_operands
          @operands.delete_if { |op| op.respond_to?(:empty?) ? op.empty? : false }
        end

        # Test if the operand is valid
        #
        # @param [AbstractOperation, AbstractComparison, Array] operand
        #   the operand to test
        #
        # @return [Boolean]
        #   true if the operand is valid
        #
        # @api private
        def valid_operand?(operand)
          if operand.respond_to?(:valid?)
            operand.valid?
          else
            true
          end
        end

        # Set self to be the operand's parent
        #
        # @return [AbstractOperation, AbstractComparison, Array]
        #   the operand that was related to self
        #
        # @api privTE
        def relate_operand(operand)
          operand.parent = self if operand.respond_to?(:parent=)
          operand
        end

        # Assert that the operand is a valid type
        #
        # @param [AbstractOperation, AbstractComparison, Array] operand
        #   the operand to test
        #
        # @return [undefined]
        #
        # @raise [ArgumentError]
        #   raised if the operand is not a valid type
        #
        # @api private
        def assert_valid_operand_type(operand)
          assert_kind_of 'operand', operand, AbstractOperation, AbstractComparison, Array
        end
      end # class AbstractOperation

      module FlattenOperation
        # Add an operand to the operation, flattening the same types
        #
        # Flattening means that if the operand is the same as the
        # operation, we should just include the operand's operands
        # in the operation and prune that part of the tree.  This results
        # in a shallower tree, is faster to match and usually generates
        # more efficient queries in the adapters.
        #
        # @param [AbstractOperation, AbstractComparison, Array] operand
        #   the operand to add
        #
        # @return [self]
        #   the operation
        #
        # @api semipublic
        def <<(operand)
          if kind_of?(operand.class)
            merge(operand.operands)
          else
            super
          end
        end
      end # module FlattenOperation

      class AndOperation < AbstractOperation
        include FlattenOperation

        slug :and

        # Match the record
        #
        # @example with a Hash
        #   operation.matches?({ :id => 1 })  # => true
        #
        # @example with a Resource
        #   operation.matches?(Blog::Article.new(:id => 1))  # => true
        #
        # @param [Resource, Hash] record
        #   the resource to match
        #
        # @return [true]
        #   true if the record matches, false if not
        #
        # @api semipublic
        def matches?(record)
          all? { |op| op.respond_to?(:matches?) ? op.matches?(record) : true }
        end

        # Minimize the operation
        #
        # @return [self]
        #   the minimized AndOperation
        # @return [AbstractOperation, AbstractComparison, Array]
        #   the minimized operation
        #
        # @api semipublic
        def minimize
          minimize_operands

          return Operation.new(:null) if any? && all? { |op| op.nil? }

          prune_operands

          one? ? first : self
        end
      end # class AndOperation

      class OrOperation < AbstractOperation
        include FlattenOperation

        slug :or

        # Match the record
        #
        # @param [Resource, Hash] record
        #   the resource to match
        #
        # @return [true]
        #   true if the record matches, false if not
        #
        # @api semipublic
        def matches?(record)
          any? { |op| op.respond_to?(:matches?) ? op.matches?(record) : true }
        end

        # Test if the operation is valid
        #
        # An OrOperation is valid if one of it's operands is valid.
        #
        # @return [Boolean]
        #   true if the operation is valid, false if not
        #
        # @api semipublic
        def valid?
          any? { |op| valid_operand?(op) }
        end

        # Minimize the operation
        #
        # @return [self]
        #   the minimized OrOperation
        # @return [AbstractOperation, AbstractComparison, Array]
        #   the minimized operation
        #
        # @api semipublic
        def minimize
          minimize_operands

          return Operation.new(:null) if any? { |op| op.nil? }

          prune_operands

          one? ? first : self
        end
      end # class OrOperation

      class NotOperation < AbstractOperation
        slug :not

        # Match the record
        #
        # @param [Resource, Hash] record
        #   the resource to match
        #
        # @return [true]
        #   true if the record matches, false if not
        #
        # @api semipublic
        def matches?(record)
          operand = self.operand
          operand.respond_to?(:matches?) ? !operand.matches?(record) : true
        end

        # Add an operand to the operation
        #
        # This will only allow a single operand to be added.
        #
        # @param [AbstractOperation, AbstractComparison, Array] operand
        #   the operand to add
        #
        # @return [self]
        #   the operation
        #
        # @api semipublic
        def <<(operand)
          assert_one_operand(operand)
          assert_no_self_reference(operand)
          super
        end

        # Return the only operand in the operation
        #
        # @return [AbstractOperation, AbstractComparison, Array]
        #   the operand
        #
        # @api semipublic
        def operand
          first
        end

        # Minimize the operation
        #
        # @return [self]
        #   the minimized NotOperation
        # @return [AbstractOperation, AbstractComparison, Array]
        #   the minimized operation
        #
        # @api semipublic
        def minimize
          minimize_operands
          prune_operands

          # factor out double negatives if possible
          operand = self.operand
          one? && instance_of?(operand.class) ? operand.operand : self
        end

        # Return the string representation of the operation
        #
        # @return [String]
        #   the string representation of the operation
        #
        # @api semipublic
        def to_s
          empty? ? '' : "NOT(#{operand.to_s})"
        end

        # Test if the operation is negated
        #
        # Defaults to return false.
        #
        # @return [Boolean]
        #   true if the operation is negated, false if not
        #
        # @api private
        def negated?
          parent = self.parent
          parent ? !parent.negated? : true
        end

        private

        # Assert there is only one operand
        #
        # @param [AbstractOperation, AbstractComparison, Array] operand
        #   the operand to test
        #
        # @return [undefined]
        #
        # @raise [ArgumentError]
        #   raised if the operand is not a valid type
        #
        # @api private
        def assert_one_operand(operand)
          unless empty? || self.operand == operand
            raise ArgumentError, "#{self.class} cannot have more than one operand"
          end
        end

        # Assert the operand is not equal to self
        #
        # @param [AbstractOperation, AbstractComparison, Array] operand
        #   the operand to test
        #
        # @return [undefined]
        #
        # @raise [ArgumentError]
        #  raised if object is appended to itself
        #
        # @api private
        def assert_no_self_reference(operand)
          if equal?(operand)
            raise ArgumentError, 'cannot append operand to itself'
          end
        end
      end # class NotOperation

      class NullOperation < AbstractOperation
        undef_method :<<
        undef_method :merge

        slug :null

        # Match the record
        #
        # A NullOperation matches every record.
        #
        # @param [Resource, Hash] record
        #   the resource to match
        #
        # @return [true]
        #   every record matches
        #
        # @api semipublic
        def matches?(record)
          record.kind_of?(Hash) || record.kind_of?(Resource)
        end

        # Test validity of the operation
        #
        # A NullOperation is always valid.
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

        private

        # Initialize a NullOperation
        #
        # @return [NullOperation]
        #   the operation
        #
        # @api semipublic
        def initialize
          @operands = Set.new
        end
      end
    end # module Conditions
  end # class Query
end # module DataMapper
