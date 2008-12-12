module DataMapper
  module Associations
    module OneToMany
      extend Assertions

      # Setup one to many relationship between two models
      #
      # @api private
      def self.setup(name, model, options = {})
        assert_kind_of 'name',    name,    Symbol
        assert_kind_of 'model',   model,   Model
        assert_kind_of 'options', options, Hash

        repository_name = model.repository.name

        model.class_eval <<-EOS, __FILE__, __LINE__
          def #{name}(query = nil)
            #{name}_association.all(query)
          end

          def #{name}=(children)
            #{name}_association.replace(children)
          end

          private

          def #{name}_association
            @#{name} ||= begin
              # TODO: this seems like a bug.  the first time the association is
              # loaded it will be using the relationship object from the repo that
              # was in effect when it was defined.  Instead it should determine the
              # repo currently in-scope, and use the association for it.

              relationship = model.relationships(#{repository_name.inspect})[#{name.inspect}]

              # TODO: do not build the query with child_key/parent_key.. use
              # child_accessor/parent_accessor.  The query should be able to
              # translate those to child_key/parent_key inside the adapter,
              # allowing adapters that don't join on PK/FK to work too.

              repository = DataMapper.repository(relationship.repository_name)
              model      = relationship.child_model
              conditions = relationship.query.merge(relationship.child_key.zip(relationship.parent_key.get(self)).to_hash)

              query = Query.new(repository, model, conditions)

              association = Proxy.new(query)

              association.relationship = relationship
              association.parent       = self

              parent_associations << association

              association
            end
          end
        EOS

        relationship = model.relationships(repository_name)[name] = Relationship.new(
          name,
          repository_name,
          options[:class_name] || Extlib::Inflection.classify(name),
          model,
          options
        )

        # FIXME: temporary until the Relationship.new API is refactored to
        # accept type as the first argument, and RelationshipChain has been
        # removed
        relationship.type = self

        relationship
      end

      class Proxy < Collection
        attr_writer :relationship, :parent

        def reload(query = nil)
          # include the child_key in reloaded records
          fields = if query.kind_of?(Hash) && query.any?
            query[:fields] = @relationship.child_key.to_a | (query[:fields] || [])
          elsif query.kind_of?(Query)
            query.update(:fields => @relationship.child_key.to_a | query.fields)
          end

          super
        end

        # TODO: document
        # @api public
        def replace(other)
          lazy_load  # lazy load so that it is always orphaned
          super
        end

        # TODO: document
        # @api public
        def clear
          lazy_load  # lazy load so that it is always orphaned
          super
        end

        # TODO: document
        # @api public
        def create(attributes = {})
          assert_parent_saved 'The parent must be saved before creating a Resource'
          super
        end

        # TODO: document
        # @api public
        def update(attributes = {}, *allowed)
          assert_parent_saved 'The parent must be saved before mass-updating the association'
          super
        end

        # TODO: document
        # @api public
        def update!(attributes = {}, *allowed)
          assert_parent_saved 'The parent must be saved before mass-updating the association without validation'
          super
        end

        # TODO: document
        # @api public
        def destroy
          assert_parent_saved 'The parent must be saved before mass-deleting the association'
          super
        end

        # TODO: document
        # @api public
        def destroy!
          assert_parent_saved 'The parent must be saved before mass-deleting the association without validation'
          super
        end

        private

        # TODO: document
        # @api private
        def new_collection(query, resources = nil, &block)
          association = self.class.new(query, &block)

          association.relationship = @relationship
          association.parent       = @parent

          # set the resources after the relationship and parent are set
          if resources
            association.replace(resources)
          end

          association
        end

        # TODO: document
        # @api private
        def relate_resource(resource)
          return if resource.nil?

          # TODO: should just set the resource parent using the mutator
          #   - this will allow the parent to be saved later and the parent
          #     reference in the child to get an id, and since it is related
          #     to the child, the child will get the correct parent id
          values = @relationship.parent_key.get(@parent)
          @relationship.child_key.set(resource, values)

          super
        end

        # TODO: document
        # @api private
        def orphan_resource(resource)
          return if resource.nil?

          # TODO: should just set the resource parent to nil using the mutator
          @relationship.child_key.set(resource, nil)

          super
        end

        def assert_parent_saved(message)
          if @parent.new_record?
            raise UnsavedParentError, message
          end
        end
      end # class Proxy
    end # module OneToMany
  end # module Associations
end # module DataMapper
