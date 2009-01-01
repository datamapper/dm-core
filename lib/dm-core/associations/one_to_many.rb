module DataMapper
  module Associations
    module OneToMany
      class Relationship < DataMapper::Associations::Relationship
        private

        # TODO: document
        # @api semipublic
        def initialize(name, child_model, parent_model, options = {})
          child_model ||= Extlib::Inflection.camelize(name.to_s.singular)
          super
        end

        # TODO: document
        # @api semipublic
        def create_helper
          return if parent_model.instance_methods(false).include?("#{name}_helper")

          parent_model.class_eval <<-EOS, __FILE__, __LINE__
            private
            def #{name}_helper
              @#{name} ||= begin
                # TODO: this seems like a bug.  the first time the association is
                # loaded it will be using the relationship object from the repo that
                # was in effect when it was defined.  Instead it should determine the
                # repo currently in-scope, and use the association for it.

                relationship = model.relationships(#{parent_repository_name.inspect})[#{name.inspect}]

                # TODO: do not build the query with child_key/parent_key.. use
                # child_accessor/parent_accessor.  The query should be able to
                # translate those to child_key/parent_key inside the adapter,
                # allowing adapters that don't join on PK/FK to work too.

                # FIXME: what if the parent key is not set yet, and the collection is
                # initialized below with the nil parent key in the query?  When you
                # save the parent and then reload the association, it will probably
                # not be found.  Test this.

                repository = DataMapper.repository(relationship.child_repository_name)
                model      = relationship.child_model
                conditions = relationship.query.merge(relationship.child_key.zip(relationship.parent_key.get(self)).to_hash)

                if relationship.max.kind_of?(Integer)
                  conditions.update(:limit => relationship.max)
                end

                query = Query.new(repository, model, conditions)

                association = OneToMany::Collection.new(query)

                association.relationship = relationship
                association.parent       = self

                child_associations << association

                association
              end
            end
          EOS
        end

        # TODO: document
        # @api semipublic
        def create_accessor
          return if parent_model.instance_methods(false).include?(name)

          parent_model.class_eval <<-EOS, __FILE__, __LINE__
            public  # TODO: make this configurable
            def #{name}(query = nil)
              #{name}_helper.all(query)
            end
          EOS
        end

        # TODO: document
        # @api semipublic
        def create_mutator
          return if parent_model.instance_methods(false).include?("#{name}=")

          parent_model.class_eval <<-EOS, __FILE__, __LINE__
            public  # TODO: make this configurable
            def #{name}=(children)
              #{name}_helper.replace(children)
            end
          EOS
        end
      end # class Relationship

      class Collection < DataMapper::Collection
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
          lazy_load  # lazy load so that children are always orphaned
          super
        end

        # TODO: document
        # @api public
        def clear
          lazy_load  # lazy load so that children are always orphaned
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

        # TODO: document
        # @api private
        def assert_parent_saved(message)
          if @parent.new_record?
            raise UnsavedParentError, message
          end
        end
      end # class Collection
    end # module OneToMany
  end # module Associations
end # module DataMapper
