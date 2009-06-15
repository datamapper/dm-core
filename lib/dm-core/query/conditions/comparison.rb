module DataMapper
  class Query
    module Conditions
      class Comparison

        # TODO: document
        # @api semipublic
        def self.new(slug, subject, value)
          if klass = comparison_class(slug)
            klass.new(subject, value)
          else
            raise "No Comparison class for `#{slug.inspect}' has been defined"
          end
        end

        # TODO: document
        # @api semipublic
        def self.comparison_class(slug)
          comparison_classes[slug] ||= AbstractComparison.descendants.detect { |comparison_class| comparison_class.slug == slug }
        end

        # TODO: document
        # @api private
        def self.slugs
          @slugs ||= AbstractComparison.descendants.map { |comparison_class| comparison_class.slug }.freeze
        end

        class << self
          private

          # TODO: document
          # @api private
          def comparison_classes
            @comparison_classes ||= {}
          end
        end
      end # class Comparison

      class AbstractComparison
        extend Deprecate

        deprecate :property, :subject

        # TODO: document
        # @api semipublic
        attr_reader :subject

        # TODO: document
        # @api semipublic
        attr_reader :value

        # TODO: document
        # @api private
        def self.descendants
          @descendants ||= Set.new
        end

        # TODO: document
        # @api private
        def self.inherited(comparison_class)
          descendants << comparison_class
        end

        # TODO: document
        # @api semipublic
        def self.slug(slug = nil)
          slug ? @slug = slug : @slug
        end

        # TODO: document
        # @api semipublic
        def valid?
          @valid
        end

        # TODO: document
        # @api semipublic
        def ==(other)
          if equal?(other)
            return true
          end

          unless other.class.respond_to?(:slug)
            return false
          end

          unless other.respond_to?(:subject)
            return false
          end

          unless other.respond_to?(:value)
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

          unless other.instance_of?(self.class)
            return false
          end

          cmp?(other, :eql?)
        end

        # TODO: document
        # @api semipublic
        def inspect
          "#<#{self.class} @subject=#{@subject.inspect} @value=#{@value.inspect}>"
        end

        # TODO: document
        # @api semipublic
        def to_s
          "#{@subject} #{comparator_string} #{@value}"
        end

        private

        # TODO: document
        # @api semipublic
        attr_reader :expected

        # TODO: document
        # @api semipublic
        def initialize(subject, value)
          @subject  = subject
          @value    = value
          @valid    = valid_value?(subject, value)
          @expected = expected_value
        end

        # TODO: document
        # @api private
        def initialize_copy(*)
          @value = @value.dup
        end

        # TODO: document
        # @api private
        def cmp?(other, operator)
          unless self.class.slug.send(operator, other.class.slug)
            return false
          end

          unless subject.send(operator, other.subject)
            return false
          end

          unless value.send(operator, other.value)
            return false
          end

          true
        end

        # TODO: document
        # @api semipublic
        def record_value(record, subject = @subject, key_type = :source_key)
          case record
            when Hash     then record_value_from_hash(record, subject, key_type)
            when Resource then record_value_from_resource(record, subject, key_type)
            else
              record
          end
        end

        # TODO: document
        # @api private
        def record_value_from_hash(hash, subject, key_type)
          hash.fetch subject, case subject
            when Property
              hash[subject.field]
            when Associations::Relationship
              subject.send(key_type).map { |property| record_value(hash, property, key_type)  }
          end
        end

        # TODO: document
        # @api private
        def record_value_from_resource(resource, subject, key_type)
          case subject
            when Property
              subject.get!(resource)
            when Associations::Relationship
              subject.send(key_type).map { |property| record_value(resource, property, key_type)  }
          end
        end

        # TODO: document
        # @api semipublic
        def expected_value
          record_value(@value, @subject, :target_key)
        end

        # TODO: document
        # @api private
        def comparator_string
          self.class.name.chomp('Comparison')
        end

        # TODO: document
        # @api private
        def valid_value?(subject, value)
          subject.valid?(value)
        end
      end # class AbstractComparison

      class EqualToComparison < AbstractComparison
        slug :eql

        # TODO: document
        # @api semipublic
        def matches?(record)
          record_value(record) == expected
        end

        private

        # TODO: document
        # @api private
        def comparator_string
          '='
        end
      end # class EqualToComparison

      class InclusionComparison < AbstractComparison
        slug :in

        # TODO: document
        # @api semipublic
        def matches?(record)
          record_value = record_value(record)
          !record_value.nil? && expected.include?(record_value)
        end

        private

        # TODO: document
        # @api private
        def comparator_string
          'IN'
        end

        # TODO: document
        # @api private
        def valid_value?(subject, value)
          unless value.kind_of?(Array) || value.kind_of?(Range) || value.kind_of?(Set)
            return false
          end

          unless value.any?
            return false
          end

          unless value.all? { |val| super(subject, val) }
            return false
          end

          true
        end

        # TODO: document
        # @api semipublic
        def expected_value
          @value.map { |value| record_value(value, @subject, :target_key) }
        end
      end # class InclusionComparison

      class RegexpComparison < AbstractComparison
        slug :regexp

        # TODO: document
        # @api semipublic
        def matches?(record)
          record_value = record_value(record)
          !record_value.nil? && record_value =~ expected
        end

        private

        # TODO: document
        # @api private
        def comparator_string
          '=~'
        end

        # TODO: document
        # @api private
        def valid_value?(subject, value)
          value.kind_of?(Regexp)
        end
      end # class RegexpComparison

      # TODO: move this to dm-more with DataObjectsAdapter plugins
      class LikeComparison < AbstractComparison
        slug :like

        # TODO: document
        # @api semipublic
        def matches?(record)
          record_value = record_value(record)
          !record_value.nil? && record_value =~ expected
        end

        private

        # TODO: document
        # @api private
        def comparator_string
          'LIKE'
        end

        # TODO: document
        # @api semipublic
        def expected_value
          Regexp.new(@value.to_s.gsub('%', '.*').gsub('_', '.'))
        end
      end # class LikeComparison

      class GreaterThanComparison < AbstractComparison
        slug :gt

        # TODO: document
        # @api semipublic
        def matches?(record)
          record_value = record_value(record)
          !record_value.nil? && record_value > expected
        end

        private

        # TODO: document
        # @api private
        def comparator_string
          '>'
        end
      end # class GreaterThanComparison

      class LessThanComparison < AbstractComparison
        slug :lt

        # TODO: document
        # @api semipublic
        def matches?(record)
          record_value = record_value(record)
          !record_value.nil? && record_value < expected
        end

        private

        # TODO: document
        # @api private
        def comparator_string
          '<'
        end
      end # class LessThanComparison

      class GreaterThanOrEqualToComparison < AbstractComparison
        slug :gte

        # TODO: document
        # @api semipublic
        def matches?(record)
          record_value = record_value(record)
          !record_value.nil? && record_value >= expected
        end

        private

        # TODO: document
        # @api private
        def comparator_string
          '>='
        end
      end # class GreaterThanOrEqualToComparison

      class LessThanOrEqualToComparison < AbstractComparison
        slug :lte

        # TODO: document
        # @api semipublic
        def matches?(record)
          record_value = record_value(record)
          !record_value.nil? && record_value <= expected
        end

        private

        # TODO: document
        # @api private
        def comparator_string
          '<='
        end
      end # class LessThanOrEqualToComparison
    end # module Conditions
  end # class Query
end # module DataMapper
