module DataMapper
  class Query
    class Path
      instance_methods.each { |m| undef_method m unless %w[ __id__ __send__ send class dup object_id kind_of? instance_of? respond_to? equal? should should_not instance_variable_set instance_variable_get extend ].include?(m.to_s) }

      include Extlib::Assertions

      # TODO: document
      # @api private
      attr_reader :repository_name

      # TODO: document
      # @api private
      attr_reader :relationships

      # TODO: document
      # @api private
      attr_reader :model

      # TODO: document
      # @api private
      attr_reader :property

      (Conditions::Comparison.slugs | [ :not ]).each do |slug|
        class_eval <<-RUBY, __FILE__, __LINE__ + 1
          def #{slug}                                                                                     # def eql
            #{"warn \"explicit use of '#{slug}' operator is deprecated\"" if slug == :eql || slug == :in} #   warn "explicit use of 'eql' operator is deprecated"
            Operator.new(self, #{slug.inspect})                                                           #   Operator.new(self, :eql)
          end                                                                                             # end
        RUBY
      end

      # TODO: document
      # @api public
      def respond_to?(method, include_private = false)
        super                                                                         ||
        (defined?(@property) ? @property.respond_to?(method, include_private) : true) ||
        @model.relationships(@repository_name).key?(method)                           ||
        @model.properties(@repository_name).key?(method)
      end

      # TODO: document
      # @api private
      def ==(other)
        if equal?(other)
          return true
        end

        unless other.respond_to?(:relationships)
          return false
        end

        unless other.respond_to?(:property)
          return false
        end

        cmp?(other, :==)
      end

      # TODO: document
      # @api private
      def eql?(other)
        if equal?(other)
          return true
        end

        unless self.class.equal?(other.class)
          return false
        end

        cmp?(other, :eql?)
      end

      # TODO: document
      # @api private
      def hash
        @relationships.hash
      end

      # TODO: document
      # @api private
      def inspect
        attrs = [
          [ :relationships, relationships ],
          [ :property,      property      ],
        ]

        "#<#{self.class.name} #{attrs.map { |k, v| "@#{k}=#{v.inspect}" }.join(' ')}>"
      end

      private

      # TODO: document
      # @api private
      def initialize(relationships, property_name = nil)
        assert_kind_of 'relationships', relationships, Array
        assert_kind_of 'property_name', property_name, Symbol, NilClass

        @relationships   = relationships
        @repository_name = @relationships.last.target_repository_name
        @model           = @relationships.last.target_model
        @property        = @model.properties(@repository_name)[property_name] if property_name
      end

      # TODO: document
      # @api private
      def cmp?(other, operator)
        relationships.send(operator, other.relationships) &&
        property.send(operator, other.property)
      end

      # TODO: document
      # @api private
      def method_missing(method, *args)
        if @property
          return @property.send(method, *args)
        end

        if relationship = @model.relationships(@repository_name)[method]
          return self.class.new(@relationships.dup << relationship)
        end

        if property = @model.properties(@repository_name)[method]
          @property = property
          return self
        end

        raise NoMethodError, "undefined property or relationship '#{method}' on #{@model}"
      end
    end # class Path
  end # class Query
end # module DataMapper
