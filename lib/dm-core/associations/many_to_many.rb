module DataMapper
  module Associations
    module ManyToMany
      class Relationship < DataMapper::Associations::OneToMany::Relationship

        # TODO: document
        # @api semipublic
        def through
          return @through if @through != Resource

          # habtm relationship traversal is deferred because we want the
          # child_model and parent_model constants to be defined, so we
          # can define the join model within their common namespace

          # TODO: pass along more options to relationship
          # TODO: make sure the property added for belongs_to in the join model is a key
          @through = DataMapper.repository(parent_repository_name) do
            join_model.belongs_to(join_relationship_name(child_model),           :class => child_model)
            parent_model.has(min..max, join_relationship_name(join_model, true), :class => join_model)
          end
        end

        # TODO: document
        # @api semipublic
        def intermediaries
          @intermediaries ||= begin
            relationships = through.child_model.relationships(through.child_repository_name)

            unless target = relationships[name] || relationships[name.to_s.singular.to_sym]
              raise NameError, "Cannot find target relationship #{name} or #{name.to_s.singular} in #{through.child_model} within the #{repository.name} repository"
            end

            [ through, through.intermediaries, target ].flatten.freeze
          end
        end

        # TODO: document
        # @api semipublic
        def query
          query = super

          # TODO: figure out a way to make it so that Query uses multiple repositories

          #query[:links] ||= []

          # TODO: traverse each relationship, and append it onto query[:links]

          # TODO: merge in conditions for each association
          #   - make sure that each relationships' conditions are factored in,
          #     which will affect the final outcome.

          query
        end

        private

        # TODO: document
        # @api semipublic
        def create_helper
          # TODO: make sure the proper Query is set up, one that includes all the links
          #   - make sure that all relationships can be intermediaries
          #   - make sure that each intermediary can be at random repositories
          #   - make sure that each intermediary can have different conditons that
          #     scope its results

          return if parent_model.instance_methods(false).include?("#{name}_helper")

          parent_model.class_eval <<-EOS, __FILE__, __LINE__
            private
            def #{name}_helper
              raise NotImplementedError
            end
          EOS
        end

        # TODO: document
        # @api private
        def join_model
          namespace, name = join_model_namespace_name

          if namespace.const_defined?(name)
            namespace.const_get(name)
          else
            namespace.const_set(name, DataMapper::Model.new)
          end
        end

        # TODO: document
        # @api private
        def join_model_namespace_name
          child_parts  = child_model.base_model.to_s.split('::')
          parent_parts = parent_model.base_model.to_s.split('::')

          name = [ child_parts.pop, parent_parts.pop ].sort.join

          namespace = Object

          # find the common namespace between the child_model and parent_model
          child_parts.zip(parent_parts) do |child_part,parent_part|
            break if child_part != parent_part
            namespace = namespace.const_get(child_part)
          end

          return namespace, name
        end

        # TODO: document
        # @api private
        def join_relationship_name(model, plural = false)
          namespace, name = join_model_namespace_name
          relationship_name = Extlib::Inflection.underscore(model.base_model.to_s.sub(/\A#{namespace.name}::/, '')).gsub('/', '_')
          (plural ? relationship_name.plural : relationship_name).to_sym
        end
      end # class Relationship

      class Collection < DataMapper::Collection
        # TODO: make sure all writers set the values in the intermediary Collections
      end # class Collection
    end # module ManyToMany
  end # module Associations
end # module DataMapper
