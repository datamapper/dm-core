module DataMapper
  module Conditions
    class Comparison
      def self.new(comparator, property, value)
        if klass = comparison_class(comparator)
          klass.new(property, value)
        else
          raise "No Comparison class for `#{comparator.inspect}' has been defined"
        end
      end

      def self.comparison_class(comparator)
        AbstractComparison.subclasses.detect{ |c| c.slug == comparator }
      end
    end

    class AbstractComparison
      attr_reader :property, :value

      def self.subclasses
        @subclasses ||= Set.new
      end

      def self.inherited(subclass)
        subclasses << subclass
      end

      def self.slug(slug = nil)
        slug ? @slug = slug : @slug
      end

      def record_value(record)
        case record
          when Hash
            record.key?(@property) ? record[@property] : record[@property.field]
          when Resource
            @property.get!(record)
        end
      end

      def comparator_string
        self.class.to_s.gsub('Comparison', '')
      end

      def to_s
        "#{property} #{comparator_string} #{value}"
      end

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

      def eql?(other)
        if equal?(other)
          return true
        end

        unless other.class.equal?(self.class)
          return false
        end

        cmp?(other, :eql?)
      end

      def inspect
        "#<#{self.class} @property=#{property.inspect} @value=#{value.inspect}>"
      end

      private

      def initialize(property, value)
        @property, @value = property, value
      end

      def cmp?(other, operator)
        unless property.send(operator, other.property)
          return false
        end

        unless value.send(operator, other.value)
          return false
        end

        true
      end
    end

    class EqualToComparison < AbstractComparison
      slug :eql

      def matches?(record)
        @value == record_value(record)
      end

      def comparator_string
        '='
      end
    end

    class InclusionComparison < AbstractComparison
      slug :in

      def matches?(record)
        record_value = record_value(record)
        !record_value.nil? && @value.include?(record_value)
      end

      def comparator_string
        'IN'
      end
    end

    class RegexpComparison < AbstractComparison
      slug :regexp

      def matches?(record)
        record_value = record_value(record)
        !record_value.nil? && record_value =~ @value
      end

      def comparator_string
        '=~'
      end

      private

      def initialize(property, value)
        value = Regexp.new(value.to_s) unless value.kind_of?(Regexp)
        super
      end
    end

    # TODO: move this to dm-more with DataObjectsAdapter plugins
    class LikeComparison < AbstractComparison
      slug :like

      def matches?(record)
        record_value = record_value(record)
        !record_value.nil? && record_value =~ regexp_value
      end

      def comparator_string
        'LIKE'
      end

      private

      def regexp_value
        @regexp_value ||= Regexp.new(@value.to_s.gsub('%', '.*').gsub('_', '.'))
      end
    end

    class GreaterThanComparison < AbstractComparison
      slug :gt

      def matches?(record)
        record_value = record_value(record)
        !record_value.nil? && record_value > @value
      end

      def comparator_string
        '>'
      end
    end

    class LessThanComparison < AbstractComparison
      slug :lt

      def matches?(record)
        record_value = record_value(record)
        !record_value.nil? && record_value < @value
      end

      def comparator_string
        '<'
      end
    end

    class GreaterThanOrEqualToComparison < AbstractComparison
      slug :gte

      def matches?(record)
        record_value = record_value(record)
        !record_value.nil? && record_value >= @value
      end

      def comparator_string
        '>='
      end
    end

    class LessThanOrEqualToComparison < AbstractComparison
      slug :lte

      def matches?(record)
        record_value = record_value(record)
        !record_value.nil? && record_value <= @value
      end

      def comparator_string
        '<='
      end
    end
  end
end
