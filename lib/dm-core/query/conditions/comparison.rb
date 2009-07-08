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
        def relationship?
          false
        end

        # TODO: document
        # @api semipublic
        def property?
          subject.kind_of?(Property)
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

          unless instance_of?(other.class)
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
          @value    = typecast_value(value)
          @valid    = valid_value?(@subject, @value)
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
        # @api private
        def typecast_value(value)
          if subject.respond_to?(:typecast)
            subject.value(subject.typecast(value))
          else
            value
          end
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
        def expected_value(value = @value)
          expected_value = record_value(value, @subject, :target_key)

          if @subject.respond_to?(:source_key)
            @subject.source_key.typecast(expected_value)
          else
            expected_value
          end
        end

        # TODO: document
        # @api private
        def valid_value?(subject, value)
          subject.valid?(value)
        end

        # TODO: document
        # @api private
        def comparator_string
          self.class.name.chomp('Comparison')
        end
      end # class AbstractComparison

      module RelationshipHandler
        # TODO: document
        # @api semipublic
        def relationship?
          subject.kind_of?(Associations::Relationship)
        end

        # TODO: document
        # @api semipublic
        def foreign_key_mapping
          relationship = subject
          source_key   = relationship.source_key
          target_key   = relationship.target_key

          source_values = []

          Array(value).each do |resource|
            next unless target_key.loaded?(resource)
            source_values << target_key.get!(resource)
          end

          if source_key.size == 1 && target_key.size == 1
            source_key    = source_key.first
            target_key    = target_key.first
            source_values = source_values.transpose.first

            if source_values.size == 1
              EqualToComparison.new(source_key, source_values.first)
            else
              InclusionComparison.new(source_key, source_values)
            end
          else
            or_operation = OrOperation.new

            source_values.each do |source_value|
              and_operation = AndOperation.new

              source_key.zip(source_value) do |property, value|
                and_operation << EqualToComparison.new(property, value)
              end

              or_operation << and_operation
            end

            or_operation
          end
        end
      end

      class EqualToComparison < AbstractComparison
        include RelationshipHandler

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
        include RelationshipHandler

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
        def typecast_value(value)
          if subject.respond_to?(:typecast) && value.respond_to?(:map)
            value.map { |val| subject.typecast(val) }
          else
            value
          end
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
          @value.map { |value| super(value) }
        end

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
          !record_value.nil? && record_value =~ expected
        end

        private

        # TODO: document
        # @api private
        def typecast_value(value)
          value
        end

        # TODO: document
        # @api private
        def valid_value?(subject, value)
          value.kind_of?(Regexp)
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
          !record_value.nil? && record_value =~ expected
        end

        private

        # TODO: document
        # @api semipublic
        def expected_value
          Regexp.new(@value.to_s.gsub('%', '.*').gsub('_', '.'))
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
