module DataMapper
  module Associations
    module ManyToMany #:nodoc:
      class Relationship < Associations::OneToMany::Relationship
        OPTIONS = (superclass::OPTIONS + [ :through ]).freeze

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
              properties = target_model.properties(relative_target_repository_name)

              if child_properties
                child_key = properties.values_at(*child_properties)
                properties.class.new(child_key).freeze
              else
                properties.key
              end
            end
        end

        alias target_key child_key

        # Intermediate association for join model
        # relationships
        #
        # Example: for :bugs association in
        #
        # class Software::Engineer
        #   include DataMapper::Resource
        #
        #   has n, :missing_tests
        #   has n, :bugs, :through => :missing_tests
        # end
        #
        # through is :missing_tests
        #
        # TODO: document a case when
        # through option is a model and
        # not an association name
        #
        # @api semipublic
        def through
          return @through if explicit_through_relationship?

          # habtm relationship traversal is deferred because we want the
          # target_model and source_model constants to be defined, so we
          # can define the join model within their common namespace

          DataMapper.repository(source_repository_name) do
            many_to_one = join_model.belongs_to(name.to_s.singularize.to_sym,            target_model, many_to_one_options)
            one_to_many = source_model.has(min..max, join_relationship_name(join_model), join_model,   one_to_many_options)

            # initialize the child_key on the many to one relationship
            # now that the source, join and target models are defined
            many_to_one.child_key

            @through = one_to_many
          end
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

              [ through, target ].map do |relationship|
                if relationship.respond_to?(:links)
                  relationship.links
                else
                  relationship
                end
              end.flatten.freeze
            end
        end

        # TODO: document
        # @api private
        def source_scope(source)
          # TODO: remove this method and inherit from Relationship

          target_key = through.target_key
          source_key = through.source_key

          scope = {}

          # TODO: handle compound keys
          if (source_values = Array(source).map { |resource| source_key.first.get(resource) }.compact).any?
            scope[target_key.first] = source_values
          end

          scope
        end

        # TODO: document
        # @api private
        def query
          # TODO: consider making this a query_for method, so that ManyToMany::Relationship#query only
          # returns the query supplied in the definition
          @many_to_many_query ||= super.merge(:links => links).freeze
        end

        private

        # TODO: document
        # @api semipublic
        def initialize(name, source_model, target_model, options = {})
          @through = options.fetch(:through)
          super
        end

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
          target_parts.zip(source_parts) do |target_part, source_part|
            break if target_part != source_part
            namespace = namespace.const_get(target_part)
          end

          return namespace, name
        end

        # TODO: document
        # @api private
        def join_relationship_name(model)
          namespace = join_model_namespace_name.first
          relationship_name = Extlib::Inflection.underscore(model.base_model.name.sub(/\A#{namespace.name}::/, '')).gsub('/', '_')
          relationship_name.pluralize.to_sym
        end

        # TODO: document
        # @api private
        def explicit_through_relationship?
          @through != Resource
        end

        # TODO: document
        # @api semipublic
        def many_to_one_options
          { :parent_key => target_key.map  { |property| property.name } }
        end

        # TODO: document
        # @api semipublic
        def one_to_many_options
          {}
        end

        # TODO: document
        # @api private
        def inverse
          raise NotImplementedError, "#{self.class}#inverse not implemented"
        end

        # Returns collection class used by this type of
        # relationship
        #
        # @api private
        def collection_class
          ManyToMany::Collection
        end
      end # class Relationship

      class Collection < Associations::OneToMany::Collection
        ##
        # Remove every Resource in the m:m Collection from the repository
        #
        # This performs a deletion of each Resource in the Collection from
        # the repository and clears the Collection.
        #
        # @return [TrueClass, FalseClass]
        #   true if the resources were successfully destroyed
        #
        # @api public
        def destroy
          unless intermediaries.destroy
            return false
          end

          super
        end

        ##
        # Remove every Resource in the m:m Collection from the repository, bypassing validation
        #
        # This performs a deletion of each Resource in the Collection from
        # the repository and clears the Collection while skipping
        # validation.
        #
        # @return [TrueClass, FalseClass]
        #   true if the resources were successfully destroyed
        #
        # @api public
        def destroy!
          unless intermediaries.destroy!
            return false
          end

          if empty?
            return true
          end

          # FIXME: use a subquery to do this more efficiently in the future
          repository_name = relationship.relative_target_repository_name_for(source)
          model           = relationship.target_model
          key             = model.key(repository_name)

          # TODO: handle compound keys
          model.all(:repository => repository_name, key.first => map { |resource| resource.key.first }).destroy!

          each { |resource| resource.reset }
          clear

          true
        end

        private

        # TODO: document
        # @api private
        def _create(safe, attributes)
          if last_relationship.respond_to?(:resource_for)
            resource = super
            if create_intermediary(safe, last_relationship => resource)
              resource
            end
          else
            if intermediary = create_intermediary(safe)
              super(safe, attributes.merge(last_relationship.inverse => intermediary))
            end
          end
        end

        # TODO: document
        # @api private
        def _update(dirty_attributes)
          assert_source_saved 'The source must be saved before mass-updating the collection'

          attributes = dirty_attributes.map { |property, value| [ property.name, value ] }.to_hash

          # FIXME: use a subquery to do this more efficiently in the future,
          key = model.key(repository.name)

          # TODO: handle compound keys
          model.all(:repository => repository_name, key.first => map { |resource| resource.key.first }).update!(attributes)
        end

        # TODO: document
        # @api private
        def _save(safe)
          resources = if loaded?
            entries
          else
            head + tail
          end

          # delete only intermediaries linked to the target orphans
          unless @orphans.empty? || intermediaries(@orphans).send(safe ? :destroy : :destroy!)
            return false
          end

          if last_relationship.respond_to?(:resource_for)
            super
            resources.all? { |resource| create_intermediary(safe, last_relationship => resource) }
          else
            if intermediary = create_intermediary(safe)
              inverse = last_relationship.inverse
              resources.map { |resource| inverse.set(resource, intermediary) }
            end

            super
          end
        end

        # TODO: document
        # @api private
        def intermediaries(resources = saved)
          through        = relationship.through
          intermediaries = through.loaded?(source) ? through.get!(source) : through.collection_for(source)
          intermediaries.all(last_relationship => resources)
        end

        # TODO: document
        # @api private
        def saved
          select { |resource| resource.saved? }
        end

        # TODO: document
        # @api private
        def create_intermediary(safe, attributes = {})
          return unless intermediaries.send(safe ? :save : :save!)

          intermediary = intermediaries.first(attributes) ||
                         intermediaries.send(safe ? :create : :create!, attributes)

          return intermediary if intermediary.saved?
        end

        # TODO: document
        # @api private
        def last_relationship
          @last_relationship ||= relationship.links.last
        end

        # TODO: document
        # @api private
        def default_attributes
          collection_default_attributes
        end

        # TODO: document
        # @api private
        def relate_resource(resource)
          collection_relate_resource(resource)
        end

        # TODO: document
        # @api private
        def orphan_resource(resource)
          collection_orphan_resource(resource)
        end
      end # class Collection
    end # module ManyToMany
  end # module Associations
end # module DataMapper
