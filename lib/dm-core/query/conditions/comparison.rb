module DataMapper
  class Query
    module Conditions
      class Comparison

        # TODO: document
        # @api semipublic
        def self.new(slug, property, value)
          if klass = comparison_class(slug)
            klass.new(property, value)
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
        # TODO: document
        # @api semipublic
        attr_reader :property

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
            when Hash
              record.key?(@property) ? record[@property] : record[@property.field]
            when Resource
              @property.get!(record)
          end
        end

        # TODO: document
        # @api semipublic
        def to_s
          "#{property} #{comparator_string} #{value}"
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

          unless other.respond_to?(:property) && other.respond_to?(:value)
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
          "#<#{self.class} @property=#{property.inspect} @value=#{value.inspect}>"
        end

        private

        # TODO: document
        # @api semipublic
        def initialize(property, value)
          @property = property
          @value    = value
        end

        # TODO: document
        # @api private
        def cmp?(other, operator)
          unless property.send(operator, other.property)
            return false
          end

          unless value.send(operator, other.value)
            return false
          end

          true
        end

        # TODO: document
        # @api private
        def comparator_string
          self.class.name.chomp('Comparison')
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
        # @api semipublic
        def initialize(property, value)
          value = Regexp.new(value.to_s) unless value.kind_of?(Regexp)
          super
        end

        # TODO: document
        # @api private
        def comparator_string
          '=~'
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
