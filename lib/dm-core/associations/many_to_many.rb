module DataMapper
  module Associations
    module ManyToMany
      class Relationship < DataMapper::Associations::OneToMany::Relationship
        # TODO: document
        # @api semipublic
        def self.collection_class
          ManyToMany::Collection
        end

        # TODO: document
        # @api semipublic
        def through
          return @through if @through != Resource

          # habtm relationship traversal is deferred because we want the
          # child_model and parent_model constants to be defined, so we
          # can define the join model within their common namespace

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

            [ through, target ].map { |r| (i = r.intermediaries).any? ? i : r }.flatten.freeze
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
        def child_key(repository_name)
          assert_kind_of 'repository_name', repository_name, Symbol

          child_repository_name = @child_repository_name || repository_name

          @child_key ||= {}

          @child_key[child_repository_name] ||= begin
            child_key = if @child_properties
              child_model.properties(child_repository_name).slice(*@child_properties)
            else
              child_model.key(child_repository_name)
            end

            PropertySet.new(child_key)
          end
        end

        # TODO: document
        # @api semipublic
        def target_for(parent_resource)
          # TODO: spec this
          #if parent_resource.new?
          #  # an unsaved parent cannot be referenced by children
          #  return
          #end

          # TODO: do not build the query with child_key/parent_key.. use
          # child_accessor/parent_accessor.  The query should be able to
          # translate those to child_key/parent_key inside the adapter,
          # allowing adapters that don't join on PK/FK to work too.

          # TODO: make sure the proper Query is set up, one that includes all the links
          #   - make sure that all relationships can be intermediaries
          #   - make sure that each intermediary can be at random repositories
          #   - make sure that each intermediary can have different conditons that
          #     scope its results

          repository     = child_repository_name ? DataMapper.repository(child_repository_name) : parent_resource.repository
          join_condition = query.merge(through.child_key(repository.name).zip(through.parent_key(parent_resource.repository.name).get(parent_resource)).to_hash)

          if max.kind_of?(Integer)
            join_condition.update(:limit => max)
          end

          Query.new(repository, child_model, join_condition)
        end

        private

        # TODO: document
        # @api private
        def join_model
          namespace, name = join_model_namespace_name

          if namespace.const_defined?(name)
            namespace.const_get(name)
          else
            model = DataMapper::Model.new do
              # all properties added to the join model are considered a key
              def property(name, type, options = {})
                options[:key] = true
                options.delete(:index)
                super
              end
            end

            namespace.const_set(name, model)
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
          namespace = join_model_namespace_name.first
          relationship_name = Extlib::Inflection.underscore(model.base_model.name.sub(/\A#{namespace.name}::/, '')).gsub('/', '_')
          (plural ? relationship_name.plural : relationship_name).to_sym
        end
      end # class Relationship

      class Collection < DataMapper::Associations::OneToMany::Collection
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
          assert_parent_saved 'The parent must be saved before creating a Resource'

          # NOTE: this is ugly as hell. this is a first draft to
          # try to figure out an approach that will create all the
          # inermediary records, in the right order, creating
          # dependencies first.  this should probably be generalized
          # so that it can also be used with new() and just have
          # it create new resources that can be saved by iterating
          # over a list, calling save() on each.

          intermediaries = @relationship.intermediaries.dup

          pivot, prev = [ nil, intermediaries.last ], nil

          intermediaries.each do |relationship|
            if relationship.kind_of?(ManyToOne::Relationship)
              break pivot = [ prev, relationship ].compact
            end

            prev = relationship
          end

          head, tail = [ @parent ], []

          while intermediaries.any?
            relationship = if pivot.first == intermediaries.first
              intermediaries.pop
            else
              intermediaries.shift
            end

            default_attributes = {}

            if relationship.kind_of?(ManyToOne::Relationship)
              if tail.any?
                values = relationship.child_key(tail.first.repository.name).get(tail.first)
                default_attributes.update(relationship.parent_key(relationship.parent_repository_name).zip(values).to_hash)
              else
                default_attributes.update(attributes)
                default_attributes.update(self.send(:default_attributes))
              end

              tail.unshift(relationship.parent_model.create(default_attributes))
            else
              if relationship == pivot.first && pivot.size == 2 && head.any?
                values = pivot.first.parent_key(head.last.repository.name).get(head.last)
                default_attributes.update(pivot.first.child_key(repository.name).map { |p| p.name }.zip(values).to_hash)

                values = pivot.last.parent_key(tail.first.repository.name).get(tail.first)
                default_attributes.update(pivot.last.child_key(repository.name).map { |p| p.name }.zip(values).to_hash)
              end

              # TODO: make a Relationship#get retrieve the association ivar value
              head << head.last.send(relationship.name).create(default_attributes)
            end
          end

          tail.last
        end

        def update(attributes = {}, *allowed)
          # TODO: update the resources in the child model
          raise NotImplementedError
        end

        def update!(attributes = {}, *allowed)
          # TODO: update the resources in the child model
          raise NotImplementedError
        end

        def save
          # TODO: create the new intermediaries
          # TODO: destroy the orphaned intermediaries
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

        private

        def relate_resource(resource)
          # TODO: queue up new intermediaries for creation

          # TODO: figure out how to DRY this up.  Should we just inherit
          # from Collection directly, and bypass OneToMany::Collection?
          return if resource.nil?

          resource.collection = self

          if resource.saved?
            @identity_map[resource.key] = resource
            @orphans.delete(resource)
          end

          resource
        end

        def orphan_resource(resource)
          # TODO: queue up orphaned intermediaries for destruction

          # TODO: figure out how to DRY this up.  Should we just inherit
          # from Collection directly, and bypass OneToMany::Collection?
          return if resource.nil?

          if resource.collection.equal?(self)
            resource.collection = nil
          end

          if resource.saved?
            @identity_map.delete(resource.key)
            @orphans << resource
          end

          resource
        end
      end # class Collection
    end # module ManyToMany
  end # module Associations
end # module DataMapper
