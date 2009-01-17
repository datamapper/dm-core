module DataMapper
  module Associations
    module OneToMany
      class Relationship < DataMapper::Associations::Relationship
        # TODO: document
        # @api semipublic
        def self.collection_class
          OneToMany::Collection
        end

        # TODO: document
        # @api semipublic
        def target_for(parent_resource)
          # TODO: spec this
          #if parent_resource.new_record?
          #  # an unsaved parent cannot have any children
          #  return
          #end

          # TODO: do not build the query with child_key/parent_key.. use
          # child_accessor/parent_accessor.  The query should be able to
          # translate those to child_key/parent_key inside the adapter,
          # allowing adapters that don't join on PK/FK to work too.

          repository = DataMapper.repository(child_repository_name)
          conditions = query.merge(child_key.zip(parent_key.get(parent_resource)).to_hash)

          if max.kind_of?(Integer)
            conditions.update(:limit => max)
          end

          Query.new(repository, child_model, conditions)
        end

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

          parent_model.class_eval <<-RUBY, __FILE__, __LINE__ + 1
            private
            def #{name}_helper
              @#{name} ||= begin
                relationship = model.relationships(repository.name)[#{name.inspect}]

                query = relationship.target_for(self)

                association = relationship.class.collection_class.new(query)

                association.relationship = relationship
                association.parent       = self

                child_associations << association

                association
              end
            end
          RUBY
        end

        # TODO: document
        # @api semipublic
        def create_accessor
          return if parent_model.instance_methods(false).include?(name)

          parent_model.class_eval <<-RUBY, __FILE__, __LINE__ + 1
            public  # TODO: make this configurable
            def #{name}(query = nil)
              #{name}_helper.all(query)
            end
          RUBY
        end

        # TODO: document
        # @api semipublic
        def create_mutator
          return if parent_model.instance_methods(false).include?("#{name}=")

          parent_model.class_eval <<-RUBY, __FILE__, __LINE__ + 1
            public  # TODO: make this configurable
            def #{name}=(children)
              #{name}_helper.replace(children)
            end
          RUBY
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
          @relationship.child_key.set(resource, [])

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
