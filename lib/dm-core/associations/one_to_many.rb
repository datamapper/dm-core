module DataMapper
  module Associations
    module OneToMany
      class Relationship < Associations::Relationship
        # TODO: document
        # @api semipublic
        def self.collection_class
          OneToMany::Collection
        end

        # TODO: document
        # @api private
        def parent_scope(parent)
          # TODO: do not build the query with child_key/parent_key.. use
          # child_accessor/parent_accessor.  The query should be able to
          # translate those to child_key/parent_key inside the adapter,
          # allowing adapters that don't join on PK/FK to work too.

          # TODO: when parent is a Collection, and it's query includes an
          # offset/limit, use it as a subquery to scope the results, rather
          # than (potentially) lazy-loading the Collection and getting
          # each resource key

          # TODO: spec what should happen when parent not saved

          # TODO: handle compound keys when OR conditions supported
          parent_values = Array(parent).map { |r| parent_key.get(r) }.select { |k| k.all? }.transpose

          child_key.zip(parent_values).to_hash
        end

        # TODO: document
        # @api semipublic
        def query_for(parent)
          Query.new(DataMapper.repository(child_repository_name), child_model, query.merge(parent_scope(parent)))
        end

        # TODO: document
        # @api semipublic
        def get(parent, query = nil)
          lazy_load(parent) unless loaded?(parent)

          collection = get!(parent)

          if query.nil?
            collection
          else
            # XXX: use query_for(parent) to explicitly set the child_key in the query
            # because we do not save a reference to the instance.  Remove when we do.
            collection.all(query_for(parent).update(query))
          end
        end

        # TODO: document
        # @api semipublic
        def set(parent, children)
          lazy_load(parent) unless loaded?(parent)
          get!(parent).replace(children)
        end

        # TODO: document
        # @api semipublic
        def set!(resource, association)
          association.relationship = self
          association.parent       = resource
          super
        end

        private

        # TODO: document
        # @api semipublic
        def initialize(name, child_model, parent_model, options = {})
          child_model ||= Extlib::Inflection.camelize(name.to_s.singular).freeze
          super
        end

        # TODO: document
        # @api semipublic
        def create_accessor
          return if parent_model.instance_methods(false).map { |m| m.to_sym }.include?(name)

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
          return if parent_model.instance_methods(false).map { |m| m.to_sym }.include?("#{name}=".to_sym)

          parent_model.class_eval <<-RUBY, __FILE__, __LINE__ + 1
            public  # TODO: make this configurable
            def #{name}=(children)
              relationships[#{name.inspect}].set(self, children)
            end
          RUBY
        end

        # TODO: document
        # @api private
        def lazy_load(parent)
          query_for = query_for(parent)
          set!(parent, self.class.collection_class.new(query_for))
        end
      end # class Relationship

      class Collection < DataMapper::Collection

        # TODO: document
        # @api private
        attr_accessor :relationship

        # TODO: document
        # @api private
        attr_accessor :parent

        # TODO: document
        # @api public
        def query
          query = super

          if parent.saved?
            # include the child_key in the results
            query.update(:fields => relationship.child_key.to_a | query.fields)

            # scope the query to the parent
            query.update(relationship.parent_scope(parent))
          end

          query
        end

        # TODO: document
        # @api public
        def reload(query = nil)
          assert_parent_saved 'The parent must be saved before reloading the collection'
          super(query.nil? ? self.query.dup : self.query.merge(query))
        end

        def all(*)
          assert_parent_saved 'The parent must be saved before further scoping the collection'
          super
        end

        # TODO: add stub methods for each finder like all(), where it raises
        # an exception when trying to scope the results before the parent is saved

        # TODO: document
        # @api public
        def replace(*)
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
        def create(*)
          assert_parent_saved 'The parent must be saved before creating a Resource'
          super
        end

        # TODO: document
        # @api public
        def update(*)
          assert_parent_saved 'The parent must be saved before mass-updating the collection'
          super
        end

        # TODO: document
        # @api public
        def update!(*)
          assert_parent_saved 'The parent must be saved before mass-updating the collection without validation'
          super
        end

        # TODO: document
        # @api public
        def save
          assert_parent_saved 'The parent must be saved before saving the collection'

          # remove reference to parent in orphans
          @orphans.each { |r| r.save }

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
          if parent.saved?
            super
          elsif !loaded?
            mark_loaded

            # TODO: update LazyArray to wrap the idiom where we move from the head/tail to the array
            #   - Update the default Collection#load_with block to use the same idiom
            @array.unshift(*@head)
            @array.concat(@tail)
            @head = @tail = nil
            @reapers.each { |r| @array.delete_if(&r) } if @reapers
            @array.freeze if frozen?
          end
        end

        # TODO: document
        # @api private
        def new_collection(query, resources = nil, &block)
          collection = self.class.new(query, &block)

          collection.relationship = relationship
          collection.parent       = parent

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

          if parent.saved?
            parent_key = relationship.parent_key
            child_key  = relationship.child_key

            child_key.set(resource, parent_key.get(parent))
          end

          super
        end

        # TODO: document
        # @api private
        def orphan_resource(resource)
          return if resource.nil?

          # TODO: should just set the resource parent to nil using the mutator
          relationship.child_key.set(resource, [])

          super
        end

        # TODO: document
        # @api private
        def assert_parent_saved(message)
          if parent.new?
            raise UnsavedParentError, message
          end
        end
      end # class Collection
    end # module OneToMany
  end # module Associations
end # module DataMapper
