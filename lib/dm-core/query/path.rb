module DataMapper
  class Query
    class Path
      include Extlib::Assertions

      # silence Object deprecation warnings
      [ :id, :type ].each { |m| undef_method m if method_defined?(m) }

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

      Query::OPERATORS.each do |sym|
        class_eval <<-RUBY, __FILE__, __LINE__ + 1
          def #{sym}                                                                                   # def eql
            #{"warn \"explicit use of '#{sym}' operator is deprecated\"" if sym == :eql || sym == :in} #   warn "explicit use of 'eql' operator is deprecated"
            Operator.new(self, #{sym.inspect})                                                         #   Operator.new(self, :eql)
          end                                                                                          # end
        RUBY
      end

      ##
      # Duck type the DM::Query::Path to act like a DM::Property
      #
      # @api private
      def field(*args)
        defined?(@property) ? @property.field(*args) : nil
      end

      ##
      # Duck type the DM::Query::Path to act like a DM::Property
      #
      # @api private
      def to_sym
        defined?(@property) ? @property.name.to_sym : @model.storage_name(@repository_name).to_sym
      end

      # TODO: document
      # @api private
      def ==(other)
        return true if equal?(other)
        return false unless other.respond_to?(:repository_name) &&
                            other.respond_to?(:relationships)   &&
                            other.respond_to?(:model)           &&
                            other.respond_to?(:property)

        cmp?(other, :==)
      end

      # TODO: document
      # @api private
      def eql?(other)
        return true if equal?(other)
        return false unless self.class.equal?(other.class)

        cmp?(other, :eql?)
      end

      # TODO: document
      # @api private
      def hash
        repository_name.hash + relationships.hash + model.hash + property.hash
      end

      # TODO: document
      # @api private
      def inspect
        attrs = [
          [ :repository_name, repository_name ],
          [ :relationships,   relationships   ],
          [ :model,           model           ],
          [ :property,        property        ],
        ]

        "#<#{self.class.name} #{attrs.map { |k, v| "@#{k}=#{v.inspect}" } * ' '}>"
      end

      private

      # TODO: document
      # @api private
      def initialize(repository, relationships, model, property_name = nil)
        assert_kind_of 'repository',    repository,    Repository
        assert_kind_of 'relationships', relationships, Array
        assert_kind_of 'model',         model,         Model
        assert_kind_of 'property_name', property_name, Symbol, NilClass

        @repository_name = repository.name
        @relationships   = relationships
        @model           = model
        @property        = @model.properties(@repository_name)[property_name] if property_name
      end

      # TODO: document
      # @api private
      def cmp?(other, operator)
        repository_name.send(operator, other.repository_name) &&
        relationships.send(operator, other.relationships)     &&
        model.send(operator, other.model)                     &&
        property.send(operator, other.property)
      end

      # TODO: document
      # @api private
      def method_missing(method, *args)
        if relationship = @model.relationships(@repository_name)[method]
          repository = DataMapper.repository(@repository_name)
          return Query::Path.new(repository, @relationships.dup << relationship, relationship.target_model)
        end

        if @model.properties(@repository_name)[method] && !defined?(@property)
          @property = @model.properties(@repository_name)[method]
          return self
        end

        raise NoMethodError, "undefined property or association '#{method}' on #{@model}"
      end
    end # class Path
  end # class Query
end # module DataMapper
