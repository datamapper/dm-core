module DataMapper
  module Associations
    module ManyToMany #:nodoc:
      class Relationship < Associations::OneToMany::Relationship
        # Returns collection class used by this type of
        # relationship
        #
        # @api semipublic
        def self.collection_class
          ManyToMany::Collection
        end

        # TODO: document
        # @api semipublic
        def through
          return @through if @through != Resource

          # habtm relationship traversal is deferred because we want the
          # target_model and source_model constants to be defined, so we
          # can define the join model within their common namespace

          @through = DataMapper.repository(source_repository_name) do
            join_model.belongs_to(join_relationship_name(target_model),          :model => target_model)
            source_model.has(min..max, join_relationship_name(join_model, true), :model => join_model)
          end

          # initialize the target_key now that the source and target model are defined
          @through.target_key

          @through
        end

        # TODO: document
        # @api semipublic
        def links
          @links ||=
            begin
              relationships = through.target_model.relationships(source_repository_name)

              unless target = relationships[name] || relationships[name.to_s.singular.to_sym]
                raise NameError, "Cannot find target relationship #{name} or #{name.to_s.singular} in #{through.target_model} within the #{source_repository_name.inspect} repository"
              end

              [ through, target ].map { |r| (i = r.links).any? ? i : r }.flatten.freeze
            end
        end

        # TODO: document
        # @api private
        def query
          @many_to_many_query ||=
            begin
              # TODO: make sure the proper Query is set up, one that includes all the links
              #   - make sure that all relationships can be links
              #   - make sure that each intermediary can be at random repositories
              #   - make sure that each intermediary can have different conditons that
              #     scope its results

              query = super.dup

              # use all links in the query links
              query[:links] = links

              # TODO: move the logic below inside Query.  It should be
              # extracting the query conditions from each relationship itself

              repository_name = source_repository_name

              # merge the conditions from each intermediary into the query
              query[:links].each do |relationship|
                repository_name = relationship.target_repository_name || repository_name
                model           = relationship.target_model

                # TODO: try to do some of this normalization when
                # assigning the Query options to the Relationship

                relationship.query.each do |key,value|
                  # TODO: figure out how to merge Query options from links
                  if Query::OPTIONS.include?(key)
                    next  # skip for now
                  end

                  case key
                    when Symbol, String
                      # TODO: turn this into a Query::Path
                      query[model.properties(repository_name)[key]] = value

                    when Property
                      # TODO: turn this into a Query::Path
                      query[key] = value

                    when Query::Path
                      query[key] = value

                    when Query::Operator
                      # TODO: if the key.target is a Query::Path, then do not look it up
                      query[key.class.new(model.properties(repository_name)[key.target], key.operator)] = value

                    else
                      raise ArgumentError, "#{key.class} not allowed in relationship query"
                  end
                end
              end

              query.freeze
            end
        end

        ##
        # Returns a set of keys that identify the target model
        #
        # @return [DataMapper::PropertySet]
        #   a set of properties that identify the target model
        #
        # @api semipublic
        def child_key
          @child_key ||=
            begin
              properties = target_model.properties(target_repository_name)

              child_key = if @child_properties
                properties.slice(*@child_properties)
              else
                properties.key
              end

              properties.class.new(child_key).freeze
            end
        end

        alias target_key child_key

        # TODO: document
        # @api private
        def source_scope(source)
          # TODO: do not build the query with target_key/source_key.. use
          # target_reader/source_reader.  The query should be able to
          # translate those to target_key/source_key inside the adapter,
          # allowing adapters that don't join on PK/FK to work too.

          # TODO: when source is a Collection, and it's query includes an
          # offset/limit, use it as a subquery to scope the results, rather
          # than (potentially) lazy-loading the Collection and getting
          # each resource key

          target_key = through.target_key
          source_key = through.source_key

          # TODO: spec what should happen when source not saved

          scope = {}

          # TODO: handle compound keys when OR conditions supported
          if (source_values = Array(source).map { |r| source_key.first.get(r) }.compact).any?
            scope[target_key.first] = source_values
          end

          scope
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
              # all properties added to the anonymous join model are considered a key
              def property(name, type, options = {})
                options[:key] = true unless options.key?(:key)
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
          target_parts = target_model.base_model.name.split('::')
          source_parts = source_model.base_model.name.split('::')

          name = [ target_parts.pop, source_parts.pop ].sort.join

          namespace = Object

          # find the common namespace between the target_model and source_model
          target_parts.zip(source_parts) do |target_part,source_part|
            break if target_part != source_part
            namespace = namespace.const_get(target_part)
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
        # TODO: document
        # @api private
        attr_accessor :relationship

        # TODO: document
        # @api private
        attr_accessor :source

        # TODO: document
        # @api public
        def reload(query = nil)
          # TODO: remove references to the intermediaries
          # TODO: reload the collection
          raise NotImplementedError
        end

        # TODO: document
        # @api public
        def replace(other)
          # TODO: wipe out the intermediaries
          # TODO: replace the collection with other
          raise NotImplementedError
        end

        # TODO: document
        # @api public
        def clear
          # TODO: clear the intermediaries
          # TODO: clear the collection
          raise NotImplementedError
        end

        # TODO: document
        # @api public
        def create(attributes = {})
          assert_source_saved 'The source must be saved before creating a Resource'

          links = @relationship.links.dup

          middle, prev = [], nil

          links.each do |relationship|
            if relationship.kind_of?(ManyToOne::Relationship)
              break middle = [ prev, relationship ]
            end

            prev = relationship
          end

          source = self.source

          until links.empty? || links.first == middle.first
            relationship = links.shift
            source = relationship.get(source).create
            return source if links.empty?
          end

          join_resource = source

          source, target = nil, nil

          until links.empty? || links.last == middle.first
            relationship = links.pop

            default_attributes = if target.nil?
              attributes.merge(self.send(:default_attributes))
            else
              relationship.source_scope(source)
            end

            source = relationship.target_model.create(default_attributes)
            target ||= source
          end

          if middle.nitems == 2
            lhs, rhs = middle
            default_attributes = rhs.source_key.map { |p| p.name }.zip(rhs.target_key.get(source))
            lhs.get(join_resource).create(default_attributes)
          end

          target
        end

        # TODO: document
        # @api public
        def update(attributes = {})
          # TODO: update the resources in the target model
          raise NotImplementedError
        end

        # TODO: document
        # @api public
        def update!(attributes = {})
          # TODO: update the resources in the target model
          raise NotImplementedError
        end

        # TODO: document
        # @api public
        def save
          # TODO: create the new intermediaries
          # TODO: destroy the orphaned intermediaries
          raise NotImplementedError
        end

        # TODO: document
        # @api public
        def destroy
          # TODO: destroy the intermediaries
          # TODO: destroy the resources in the target model
          raise NotImplementedError
        end

        # TODO: document
        # @api public
        def destroy!
          # TODO: destroy! the intermediaries
          # TODO: destroy! the resources in the target model
          raise NotImplementedError
        end

        private

        # TODO: document
        # @api private
        def relate_resource(resource)
          # TODO: queue up new intermediaries for creation

          # TODO: figure out how to DRY this up.  Should we just inherit
          # from Collection directly, and bypass OneToMany::Collection?
          return if resource.nil?

          resource.collection = self

          if resource.saved?
            @identity_map[resource.key] = resource
            @orphans.delete(resource)
          else
            resource.attributes = default_attributes.except(*resource.loaded_attributes.map { |p| p.name })
          end

          resource
        end

        # TODO: document
        # @api private
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
