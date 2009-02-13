module DataMapper
  module Associations
    module ManyToOne
      class Relationship < Associations::Relationship
        # TODO: document
        # @api semipublic
        def query_for(child)
          # TODO: do not build the query with child_key/parent_key.. use
          # child_accessor/parent_accessor.  The query should be able to
          # translate those to child_key/parent_key inside the adapter,
          # allowing adapters that don't join on PK/FK to work too.

          # TODO: when parent is a Collection, and it's query includes an
          # offset/limit, use it as a subquery to scope the results, rather
          # than (potentially) lazy-loading the Collection and getting
          # each resource key

          # TODO: handle compound keys when OR conditions supported
          child_values = case child
            when Resource               then child_key.get(child)
            when DataMapper::Collection then child.map { |r| child_key.get(r) }.transpose
          end

          if child_values.any? { |v| v.blank? }
            # child must have a valid reference to the parent
            return
          end

          options = query.merge(parent_key.zip(child_values).to_hash)
          Query.new(DataMapper.repository(parent_repository_name), parent_model, options)
        end

        def get(child, query = nil)
          # TODO: when Resource can be matched against conditions
          # always set the ivar, but return the resource only if
          # it matches the conditions

          return get!(child) if query.nil? && loaded?(child)

          unless query_for = query_for(child)
            return
          end

          if query
            query_for.update(query)
          end

          unless parent = parent_model.first(query_for)
            return
          end

          set!(child, parent)
        end

        def set(child, parent)
          child_key.set(child, parent_key.get(parent))
          set!(child, parent)
        end

        private

        # TODO: document
        # @api semipublic
        def initialize(name, child_model, parent_model, options = {})
          parent_model ||= Extlib::Inflection.camelize(name)
          options        = options.merge(:min => 0, :max => 1)
          super
        end

        # TODO: document
        # @api semipublic
        def create_accessor
          return if child_model.instance_methods(false).include?(name)

          child_model.class_eval <<-RUBY, __FILE__, __LINE__ + 1
            public  # TODO: make this configurable

            # FIXME: if the accessor is used, caching nil in the ivar
            # and then the FK(s) are set, the cache in the accessor should
            # be cleared.

            def #{name}(query = nil)
              relationships[#{name.inspect}].get(self, query)
            end
          RUBY
        end

        # TODO: document
        # @api semipublic
        def create_mutator
          return if child_model.instance_methods(false).include?("#{name}=")

          child_model.class_eval <<-RUBY, __FILE__, __LINE__ + 1
            public  # TODO: make this configurable
            def #{name}=(parent)
              relationships[#{name.inspect}].set(self, parent)
            end
          RUBY
        end

        # TODO: document
        # @api private
        def property_prefix
          name
        end
      end # class Relationship
    end # module ManyToOne
  end # module Associations
end # module DataMapper
