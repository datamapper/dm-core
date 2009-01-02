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
          query = super.dup

          # use all intermediaries, besides "through", in the query links
          query[:links] = intermediaries[1..-1]

          # TODO: move the logic below inside Query.  It should be
          # extracting the query conditions from each relationship itself

          # merge the conditions from each intermediary into the query
          intermediaries.each do |relationship|

            # TODO: refactor this with source/target terminology.  Many relationships would
            # have the child as the target, and the parent as the source, while OneToMany
            # relationships would be reversed.  This will also clean up code in the DO adapter

            repository_name, model = case relationship
              when ManyToMany::Relationship, OneToMany::Relationship, OneToOne::Relationship
                [ relationship.child_repository_name, relationship.child_model ]
              when ManyToOne::Relationship
                [ relationship.parent_repository_name, relationship.parent_model ]
            end

            # TODO: create a semipublic method in Query that normalizes to a Query::Operator
            # when given a default model.  In the case of Symbol or String, lookup the
            # property within the default model.  It should recursively unwrap
            # Query::Operator values and make sure the target is a Property
            # or a Query::Path object.

            relationship.query.each do |key,value|
              case key
                when Symbol, String
                  query[ model.properties(repository_name)[key] ] = value
                when Property, Query::Path
                  query[key] = value
                when Query::Operator
                  # TODO: if the key.target is a Property, then do not look it up
                  query[ key.class.new(model.properties(repository_name)[key.target], key.operator) ] = value
                else
                  raise ArgumentError, "#{key.class} not allowed in relationship query"
              end
            end
          end

          query.freeze
        end

        # TODO: document
        # @api semipublic
        def child_key
          @child_key ||= begin
            child_key = if @child_properties
              child_model.properties(@child_repository_name).slice(*@child_properties)
            else
              child_model.key(@child_repository_name)
            end

            PropertySet.new(child_key)
          end
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

          # TODO: this is mostly cut/pasted from one-to-many associations.  Refactor
          # this once it is working properly.

          parent_model.class_eval <<-RUBY, __FILE__, __LINE__ + 1
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
                conditions = relationship.query.merge(relationship.through.child_key.zip(relationship.through.parent_key.get(self)).to_hash)

                if relationship.max.kind_of?(Integer)
                  conditions.update(:limit => relationship.max)
                end

                query = Query.new(repository, model, conditions)

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
          child_parts  = child_model.base_model.name.split('::')
          parent_parts = parent_model.base_model.name.split('::')

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
          relationship_name = Extlib::Inflection.underscore(model.base_model.name.sub(/\A#{namespace.name}::/, '')).gsub('/', '_')
          (plural ? relationship_name.plural : relationship_name).to_sym
        end
      end # class Relationship

      class Collection < DataMapper::Collection
        attr_writer :relationship, :parent

        def reload(query = nil)
          # TODO: remove references to the intermediaries
          # TODO: reload the collection
          raise NotImplementedError
        end

        def replace(other)
          # TODO: wipe out the intermediaries
          # TODO: replace the collection with other
          raise NotImplementedError
        end

        def clear
          # TODO: clear the intermediaries
          # TODO: clear the collection
          raise NotImplementedError
        end

        def create(attributes = {})
          # TODO: create the resources in the intermediaries
          # TODO: create the resource in the child model
          raise NotImplementedError
        end

        def update(attributes = {}, *allowed)
          # TODO: update the resources in the child model
          raise NotImplementedError
        end

        def update!(attributes = {}, *allowed)
          # TODO: update the resources in the child model
          #   - consider using a sub-query for this
          #   - should a sub-query be used for all Collections?
          raise NotImplementedError
        end

        def destroy
          # TODO: destroy the intermediaries
          # TODO: destroy the resources in the child model
          raise NotImplementedError
        end

        def destroy!
          # TODO: destroy! the intermediaries
          # TODO: destroy! the resources in the child model
          raise NotImplementedError
        end

      end # class Collection
    end # module ManyToMany
  end # module Associations
end # module DataMapper
