# TODO: instead of an Array of Path objects, create a Relationship
# on the fly using :through on the previous relationship, creating a
# chain.  Query::Path could then be a thin wrapper that specifies extra
# conditions on the Relationships, like the target property o match
# on.

module DataMapper
  class Query
    class Path
      # TODO: replace this with BasicObject
      instance_methods.each do |method|
        next if method =~ /\A__/ ||
          %w[ send class dup object_id kind_of? instance_of? respond_to? equal? should should_not instance_variable_set instance_variable_get instance_variable_defined? extend hash inspect copy_object ].include?(method.to_s)
        undef_method method
      end

      include Extlib::Assertions
      extend Equalizer

      equalize :relationships, :property

      # @api semipublic
      attr_reader :repository_name

      # @api semipublic
      attr_reader :relationships

      # @api semipublic
      attr_reader :model

      # @api semipublic
      attr_reader :property

      (Conditions::Comparison.slugs | [ :not ]).each do |slug|
        class_eval <<-RUBY, __FILE__, __LINE__ + 1
          def #{slug}                                                                                                    # def eql
            #{"warn \"explicit use of '#{slug}' operator is deprecated (#{caller[0]})\"" if slug == :eql || slug == :in} #   warn "explicit use of 'eql' operator is deprecated (#{caller[0]})"
            Operator.new(self, #{slug.inspect})                                                                          #   Operator.new(self, :eql)
          end                                                                                                            # end
        RUBY
      end

      # @api public
      def kind_of?(klass)
        super || (defined?(@property) ? @property.kind_of?(klass) : false)
      end

      # @api public
      def instance_of?(klass)
        super || (defined?(@property) ? @property.instance_of?(klass) : false)
      end

      # @api semipublic
      def respond_to?(method, include_private = false)
        super                                                                   ||
        (defined?(@property) && @property.respond_to?(method, include_private)) ||
        @model.relationships(@repository_name).key?(method)                     ||
        @model.properties(@repository_name).named?(method)
      end

      private

      # @api semipublic
      def initialize(relationships, property_name = nil)
        assert_kind_of 'relationships', relationships, Array
        assert_kind_of 'property_name', property_name, Symbol, NilClass

        @relationships = relationships.dup

        last_relationship = @relationships.last
        @repository_name  = last_relationship.relative_target_repository_name
        @model            = last_relationship.target_model

        if property_name
          @property = @model.properties(@repository_name)[property_name] ||
            raise(ArgumentError, "Unknown property '#{property_name}' in #{@model}")
        end
      end

      # @api semipublic
      def method_missing(method, *args)
        if @property
          return @property.send(method, *args)
        end

        path_class = self.class

        if relationship = @model.relationships(@repository_name)[method]
          return path_class.new(@relationships.dup << relationship)
        end

        if @model.properties(@repository_name).named?(method)
          return path_class.new(@relationships, method)
        end

        raise NoMethodError, "undefined property or relationship '#{method}' on #{@model}"
      end
    end # class Path
  end # class Query
end # module DataMapper
