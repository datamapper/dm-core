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
        def query_for(parent)
          # TODO: do not build the query with child_key/parent_key.. use
          # child_accessor/parent_accessor.  The query should be able to
          # translate those to child_key/parent_key inside the adapter,
          # allowing adapters that don't join on PK/FK to work too.

          # TODO: when parent is a Collection, and it's query includes an
          # offset/limit, use it as a subquery to scope the results, rather
          # than (potentially) lazy-loading the Collection and getting
          # each resource key

          # TODO: handle compound keys when OR conditions supported
          parent_values = case parent
            when Resource               then parent_key.get(parent)
            when DataMapper::Collection then parent.map { |r| parent_key.get(r) }.transpose
          end

          # TODO: spec what should happen when parent not saved

          options = query.merge(child_key.zip(parent_values).to_hash)
          Query.new(DataMapper.repository(child_repository_name), child_model, options)
        end

        def get(parent, query = nil)
          collection = get!(parent) || begin
            query_for = query_for(parent)

            collection = self.class.collection_class.new(query_for)

            collection.relationship = self
            collection.parent       = parent

            # TODO: make this public
            parent.send(:child_associations) << collection

            set!(parent, collection)
          end

          collection.all(query)
        end

        def set(parent, children)
          original = get!(parent)

          if children == original
            return original
          end

          set!(parent, original.replace(children))
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
        def create_accessor
          return if parent_model.instance_methods(false).include?(name)

          parent_model.class_eval <<-RUBY, __FILE__, __LINE__ + 1
            public  # TODO: make this configurable
            def #{name}(query = nil)
              relationships[#{name.inspect}].get(self, query)
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
              relationships[#{name.inspect}].set(self, children)
            end
          RUBY
        end
      end # class Relationship

      class Collection < DataMapper::Collection
        attr_writer :relationship, :parent

        # TODO: document
        # @api public
        def reload(query = nil)
          query = query.nil? ? self.query.dup : self.query.merge(query)

          # include the child_key in reloaded records
          super(query.update(:fields => @relationship.child_key.to_a | query.fields))
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
          assert_parent_saved 'The parent must be saved before mass-updating the collection'
          super
        end

        # TODO: document
        # @api public
        def update!(attributes = {}, *allowed)
          assert_parent_saved 'The parent must be saved before mass-updating the collection without validation'
          super
        end

        # TODO: document
        # @api public
        def destroy
          assert_parent_saved 'The parent must be saved before mass-deleting the collection'
          super
        end

        # TODO: document
        # @api public
        def destroy!
          assert_parent_saved 'The parent must be saved before mass-deleting the collection without validation'
          super
        end

        private

        def lazy_load
          if @parent.new?
            return
          end
          super
        end

        # TODO: document
        # @api private
        def new_collection(query, resources = nil, &block)
          collection = self.class.new(query, &block)

          collection.relationship = @relationship
          collection.parent       = @parent

          # set the resources after the relationship and parent are set
          if resources
            collection.replace(resources)
          end

          collection
        end

        # TODO: document
        # @api private
        def relate_resource(resource)
          return if resource.nil?

          # TODO: should just set the resource parent using the mutator
          #   - this will allow the parent to be saved later and the parent
          #     reference in the child to get an id, and since it is related
          #     to the child, the child will get the correct parent id

          parent_key = @relationship.parent_key
          child_key  = @relationship.child_key

          child_key.set(resource, parent_key.get(@parent))

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
          if @parent.new?
            raise UnsavedParentError, message
          end
        end
      end # class Collection
    end # module OneToMany
  end # module Associations
end # module DataMapper
