module DataMapper
  module Associations
    module ManyToMany
      class Relationship < Associations::OneToMany::Relationship
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
            join_model.belongs_to(join_relationship_name(child_model),           :model => child_model)
            parent_model.has(min..max, join_relationship_name(join_model, true), :model => join_model)
          end
        end

        # TODO: document
        # @api semipublic
        def intermediaries
          @intermediaries ||=
            begin
              relationships = through.child_model.relationships(parent_repository_name)

              unless target = relationships[name] || relationships[name.to_s.singular.to_sym]
                raise NameError, "Cannot find target relationship #{name} or #{name.to_s.singular} in #{through.child_model} within the #{parent_repository_name.inspect} repository"
              end

              [ through, target ].map { |r| (i = r.intermediaries).any? ? i : r }.flatten.freeze
            end
        end

        # TODO: document
        # @api private
        def query
          @many_to_many_query ||=
            begin
              query = super.dup

              # use all intermediaries in the query links
              query[:links] = intermediaries

              # TODO: move the logic below inside Query.  It should be
              # extracting the query conditions from each relationship itself

              default_repository_name = parent_repository_name

              # merge the conditions from each intermediary into the query
              query[:links].each do |relationship|

                # TODO: refactor this with source/target terminology.  Many relationships would
                # have the child as the target, and the parent as the source, while OneToMany
                # relationships would be reversed.  This will also clean up code in the DO adapter

                repository_name = nil
                model           = nil

                if relationship.kind_of?(ManyToOne::Relationship)
                  repository_name = relationship.parent_repository_name || default_repository_name
                  model           = relationship.parent_model
                else
                  repository_name = relationship.child_repository_name || default_repository_name
                  model           = relationship.child_model
                end

                # TODO: try to do some of this normalization when
                # assigning the Query options to the Relationship

                relationship.query.each do |key,value|
                  # TODO: figure out how to merge Query options from intermediaries
                  if Query::OPTIONS.include?(key)
                    next  # skip for now
                  end

                  case key
                    when Symbol, String

                      # TODO: turn this into a Query::Path
                      query[ model.properties(repository_name)[key] ] = value

                    when Property

                      # TODO: turn this into a Query::Path
                      query[key] = value

                    when Query::Path
                      query[key] = value

                    when Query::Operator

                      # TODO: if the key.target is a Query::Path, then do not look it up
                      query[ key.class.new(model.properties(repository_name)[key.target], key.operator) ] = value

                    else
                      raise ArgumentError, "#{key.class} not allowed in relationship query"
                  end
                end

                # set the default repository for the next relationship in the chain
                default_repository_name = repository_name
              end

              query.freeze
            end
        end

        # TODO: document
        # @api semipublic
        def child_key
          @child_key ||=
            begin
              child_key = if @child_properties
                child_model.properties(child_repository_name).slice(*@child_properties)
              else
                child_model.key(child_repository_name)
              end

              PropertySet.new(child_key).freeze
            end
        end

        # TODO: document
        # @api semipublic
        def query_for(parent)
          # TODO: do not build the query with child_key/parent_key.. use
          # child_accessor/parent_accessor.  The query should be able to
          # translate those to child_key/parent_key inside the adapter,
          # allowing adapters that don't join on PK/FK to work too.

          # TODO: make sure the proper Query is set up, one that includes all the links
          #   - make sure that all relationships can be intermediaries
          #   - make sure that each intermediary can be at random repositories
          #   - make sure that each intermediary can have different conditons that
          #     scope its results

          child_key  = through.child_key
          parent_key = through.parent_key

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

        private

        # TODO: document
        # @api private
        def join_model
          namespace, name = join_model_namespace_name

          if namespace.const_defined?(name)
            namespace.const_get(name)
          else
            model = Model.new do
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

      class Collection < Associations::OneToMany::Collection
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
                child_key  = relationship.child_key
                parent_key = relationship.parent_key

                parent_key.zip(child_key.get(tail.first)) { |p,v| default_attributes[p.name] = v }
              else
                default_attributes.update(attributes)
                default_attributes.update(self.send(:default_attributes))
              end

              tail.unshift(relationship.parent_model.create(default_attributes))
            else
              if relationship == pivot.first && pivot.size == 2 && head.any?
                head_parent_key = pivot.first.parent_key
                head_child_key  = pivot.first.child_key

                tail_parent_key = pivot.last.parent_key
                tail_child_key  = pivot.last.child_key

                head_child_key.zip(head_parent_key.get(head.last))  { |p,v| default_attributes[p.name] = v }
                tail_child_key.zip(tail_parent_key.get(tail.first)) { |p,v| default_attributes[p.name] = v }
              end

              head << relationship.get(head.last).create(default_attributes)
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
