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
          child_values = Array(child).map { |r| child_key.get(r).first }.compact

          options = query.merge(parent_key.zip(child_values).to_hash)
          Query.new(DataMapper.repository(parent_repository_name), parent_model, options)
        end

        # TODO: document
        # @api semipublic
        def get(child, query = nil)
          return unless loaded?(child) || lazy_load(child)

          resource = get!(child)

          if query.nil?
            resource
          else
            # TODO: when Resource can be matched against conditions
            # easily, return the resource if it matches, otherwise
            # return nil
            if resource.saved?
              parent_model.first(resource.to_query.update(query))
            else
              # TODO: remove this condition when in-memory objects
              # can be matched
              resource
            end
          end
        end

        # TODO: document
        # @api semipublic
        def set(child, parent)
          child_key.set(child, parent_key.get(parent))
          set!(child, parent)
        end

        private

        # TODO: document
        # @api semipublic
        def initialize(name, child_model, parent_model, options = {})
          parent_model ||= Extlib::Inflection.camelize(name).freeze
          options        = options.merge(:min => 0, :max => 1)
          super
        end

        # TODO: document
        # @api semipublic
        def create_accessor
          return if child_model.instance_methods(false).map { |m| m.to_sym }.include?(name)

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
          return if child_model.instance_methods(false).map { |m| m.to_sym }.include?("#{name}=".to_sym)

          child_model.class_eval <<-RUBY, __FILE__, __LINE__ + 1
            public  # TODO: make this configurable
            def #{name}=(parent)
              relationships[#{name.inspect}].set(self, parent)
            end
          RUBY
        end

        # TODO: document
        # @api private
        def lazy_load(child)

          # lazy load if the child key is not nil for at least one child
          if Array(child).all? { |r| child_key.get(r).nil? }
            return
          end

          query_for = query_for(child)

          if query
            query_for.update(query)
          end

          unless parent = parent_model.first(query_for)
            return
          end

          # if successful should always return the parent, otherwise nil
          set!(child, parent)
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
