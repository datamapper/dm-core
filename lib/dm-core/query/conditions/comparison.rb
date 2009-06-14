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
        def record_value(record)
          case record
            when Hash     then record_value_from_hash(record)
            when Resource then record_value_from_resource(record)
            else
              record
          end
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

          unless other.class.respond_to?(:slug) && other.class.slug == self.class.slug
            return false
          end

          unless other.respond_to?(:subject) && other.respond_to?(:value)
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

          unless other.class.equal?(self.class)
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
        def initialize(subject, value)
          @subject = subject
          @value   = value
          @valid   = valid_value?(subject, value)
        end

        # TODO: document
        # @api private
        def initialize_copy(*)
          @value = @value.dup
        end

        # TODO: document
        # @api private
        def cmp?(other, operator)
          unless subject.send(operator, other.subject)
            return false
          end

          unless value.send(operator, other.value)
            return false
          end

          true
        end

        # TODO: document
        # @api private
        def record_value_from_hash(hash)
          hash.fetch(@subject, hash[@subject.field])
        end

        # TODO: document
        # @api private
        def record_value_from_resource(resource)
          @subject.get!(resource)
        end

        # TODO: document
        # @api private
        def comparator_string
          self.class.name.chomp('Comparison')
        end

        # TODO: document
        # @api private
        def valid_value?(subject, value)
          value.kind_of?(subject.primitive) || (value.nil? && subject.nullable?)
        end
      end # class AbstractComparison

      class EqualToComparison < AbstractComparison
        slug :eql

        # TODO: document
        # @api semipublic
        def matches?(record)
          @value == record_value(record)
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
          !record_value.nil? && @value.include?(record_value)
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
      end # class InclusionComparison

      class RegexpComparison < AbstractComparison
        slug :regexp

        # TODO: document
        # @api semipublic
        def matches?(record)
          record_value = record_value(record)
          !record_value.nil? && record_value =~ @value
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
          !record_value.nil? && record_value =~ regexp_value
        end

        private

        # TODO: move this into the initialize method
        # TODO: document
        # @api semipublic
        def regexp_value
          @regexp_value ||= Regexp.new(@value.to_s.gsub('%', '.*').gsub('_', '.'))
        end

        # TODO: document
        # @api private
        def comparator_string
          'LIKE'
        end
      end # class LikeComparison

      class GreaterThanComparison < AbstractComparison
        slug :gt

        # TODO: document
        # @api semipublic
        def matches?(record)
          record_value = record_value(record)
          !record_value.nil? && record_value > @value
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
          !record_value.nil? && record_value < @value
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
          !record_value.nil? && record_value >= @value
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
          !record_value.nil? && record_value <= @value
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
