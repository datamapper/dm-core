module DataMapper
  module Associations
    module ManyToMany #:nodoc:
      class Relationship < Associations::OneToMany::Relationship
        OPTIONS = (superclass::OPTIONS + [ :through, :via ]).freeze

        ##
        # Returns a set of keys that identify the target model
        #
        # @return [DataMapper::PropertySet]
        #   a set of properties that identify the target model
        #
        # @api semipublic
        def child_key
          return @child_key if defined?(@child_key)

          properties = target_model.properties(relative_target_repository_name)

          @child_key = if child_properties
            child_key = properties.values_at(*child_properties)
            properties.class.new(child_key).freeze
          else
            properties.key
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
            @through = source_model.has(min..max, join_relationship_name,  join_model,   one_to_many_options)
            @via     = join_model.belongs_to(name.to_s.singularize.to_sym, target_model, many_to_one_options)
          end

          # initialize the child_key now that the source, join and
          # target models are defined
          @via.child_key

          @through
        end

        # TODO: document
        # @api semipublic
        def via
          return @via if defined?(@via)

          repository_name = through.relative_target_repository_name
          relationships   = through.target_model.relationships(repository_name)
          name            = (options[:via] || options[:remote_name] || self.name).to_s

          unless via = relationships[name] || relationships[name.singularize]
            raise NameError, "Cannot find relationship #{name.singularize} or #{name} in #{through.target_model} within the #{repository_name.inspect} repository"
          end

          @via = via
        end

        # TODO: document
        # @api semipublic
        def links
          return @links if defined?(@links)

          @links = []
          links  = [ through, via ]

          while relationship = links.shift
            if relationship.respond_to?(:links)
              links.unshift(*relationship.links)
            else
              @links << relationship
            end
          end

          @links.freeze
        end

        # TODO: document
        # @api private
        def source_scope(source)
          # TODO: remove this method and inherit from Relationship

          target_key = through.target_key
          source_key = through.source_key

          # TODO: handle compound keys
          raise NotImplementedError, "Cannot work with compound keys in #{through.target_model} yet" if target_key.size > 1

          scope = {}

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

        # TODO: document
        # @api private
        def inherited_by(model)
          relationship = super
          if explicit_through_relationship? || target_model?
            relationship.instance_variable_set(:@through, through.inherited_by(model))
          end
          relationship
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
              # all properties added to the anonymous join model are keys by default
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
        def join_relationship_name
          namespace = join_model_namespace_name.first
          relationship_name = Extlib::Inflection.underscore(join_model.name.sub(/\A#{namespace.name}::/, '')).tr('/', '_')
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
          { :parent_key => target_key.map { |property| property.name } }
        end

        # TODO: document
        # @api semipublic
        def one_to_many_options
          { :parent_key => source_key.map { |property| property.name } }
        end

        # Returns the inverse relationship class
        #
        # @api private
        def inverse_class
          self.class
        end

        # TODO: document
        # @api private
        def invert
          inverse_class.new(inverse_name, parent_model, child_model, inverted_options)
        end

        # TODO: document
        # @api private
        def inverted_options
          options.only(*OPTIONS - [ :min, :max ]).update(
            :child_key  => parent_key.map { |property| property.name },
            :parent_key => child_key.map  { |property| property.name },
            :inverse    => self
          )
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
          # FIXME: use a subquery to do this more efficiently in the future
          key = model.key(repository_name)
          raise NotImplementedError, "#{self.class}#destroy! does not work with compound keys in #{model}" if key.size > 1

          unless intermediaries.destroy!
            return false
          end

          if empty?
            return true
          end

          model.all(:repository => repository_name, key.first => map { |resource| resource.key.first }).destroy!

          each { |resource| resource.reset }
          clear

          true
        end

        private

        # TODO: document
        # @api private
        def _create(safe, attributes)
          if via.respond_to?(:resource_for)
            resource = super
            if create_intermediary(safe, via => resource)
              resource
            end
          else
            if intermediary = create_intermediary(safe)
              super(safe, attributes.merge(via.inverse => intermediary))
            end
          end
        end

        # TODO: document
        # @api private
        def _update(dirty_attributes)
          assert_source_saved 'The source must be saved before mass-updating the collection'

          # FIXME: use a subquery to do this more efficiently in the future
          key = model.key(repository_name)
          raise NotImplementedError, "#{self.class}#update and #{self.class}#update! do not work with compound keys in #{model}" if key.size > 1

          attributes = dirty_attributes.map { |property, value| [ property.name, value ] }.to_hash

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

          if via.respond_to?(:resource_for)
            super
            resources.all? { |resource| create_intermediary(safe, via => resource) }
          else
            if intermediary = create_intermediary(safe)
              inverse = via.inverse
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
          intermediaries.all(via => resources)
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
        def via
          relationship.via
        end

        # TODO: document
        # @api private
        def default_attributes
          collection_default_attributes
        end

        # TODO: document
        # @api private
        def repository_name
          relationship.relative_target_repository_name_for(source)
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
