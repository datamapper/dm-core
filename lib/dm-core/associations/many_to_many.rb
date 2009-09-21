module DataMapper
  module Associations
    module ManyToMany #:nodoc:
      class Relationship < Associations::OneToMany::Relationship
        extend Chainable

        OPTIONS = superclass::OPTIONS.dup << :through << :via

        # Returns a set of keys that identify the target model
        #
        # @return [DataMapper::PropertySet]
        #   a set of properties that identify the target model
        #
        # @api semipublic
        def child_key
          return @child_key if defined?(@child_key)

          repository_name = child_repository_name || parent_repository_name
          properties      = child_model.properties(repository_name)

          @child_key = if @child_properties
            child_key = properties.values_at(*@child_properties)
            properties.class.new(child_key).freeze
          else
            properties.key
          end
        end

        # TODO: document
        # @api semipublic
        alias target_key child_key

        # Intermediate association for through model
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
          return @through if defined?(@through)

          if options[:through].kind_of?(Associations::Relationship)
            return @through = options[:through]
          end

          repository_name = source_repository_name
          relationships   = source_model.relationships(repository_name)
          name            = through_relationship_name

          @through = relationships[name] ||
            DataMapper.repository(repository_name) do
              source_model.has(min..max, name, through_model, one_to_many_options)
            end

          @through.child_key

          @through
        end

        # TODO: document
        # @api semipublic
        def via
          return @via if defined?(@via)

          if options[:via].kind_of?(Associations::Relationship)
            return @via = options[:via]
          end

          repository_name = through.relative_target_repository_name
          through_model   = through.target_model
          relationships   = through_model.relationships(repository_name)
          singular_name   = name.to_s.singularize.to_sym

          @via = relationships[options[:via]] ||
            relationships[name]               ||
            relationships[singular_name]

          @via ||= if anonymous_through_model?
            DataMapper.repository(repository_name) do
              through_model.belongs_to(singular_name, target_model, many_to_one_options)
            end
          else
            raise UnknownRelationshipError, "No relationships named #{name} or #{singular_name} in #{through_model}"
          end

          @via.child_key

          @via
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
          { through.inverse => source }
        end

        # TODO: document
        # @api private
        def query
          # TODO: consider making this a query_for method, so that ManyToMany::Relationship#query only
          # returns the query supplied in the definition
          @many_to_many_query ||= super.merge(:links => links).freeze
        end

        # Eager load the collection using the source as a base
        #
        # @param [Resource, Collection] source
        #   the source to query with
        # @param [Query, Hash] other_query
        #   optional query to restrict the collection
        #
        # @return [ManyToMany::Collection]
        #   the loaded collection for the source
        #
        # @api private
        def eager_load(source, other_query = nil)
          # FIXME: enable SEL for m:m relationships
          source.model.all(query_for(source, other_query))
        end

        private

        # TODO: document
        # @api private
        def through_model
          namespace, name = through_model_namespace_name

          if namespace.const_defined?(name)
            namespace.const_get(name)
          else
            model = Model.new do
              # all properties added to the anonymous through model are keys by default
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
        def through_model_namespace_name
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
        def through_relationship_name
          if anonymous_through_model?
            namespace = through_model_namespace_name.first
            relationship_name = Extlib::Inflection.underscore(through_model.name.sub(/\A#{namespace.name}::/, '')).tr('/', '_')
            relationship_name.pluralize.to_sym
          else
            options[:through]
          end
        end

        # Check if the :through association uses an anonymous model
        #
        # An anonymous model means that DataMapper creates the model
        # in-memory, and sets the relationships to join the source
        # and the target model.
        #
        # @return [Boolean]
        #   true if the through model is anonymous
        #
        # @api private
        def anonymous_through_model?
          options[:through] == Resource
        end

        # TODO: document
        # @api semipublic
        chainable do
          def many_to_one_options
            { :parent_key => target_key.map { |property| property.name } }
          end
        end

        # TODO: document
        # @api semipublic
        chainable do
          def one_to_many_options
            { :parent_key => source_key.map { |property| property.name } }
          end
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
          links   = self.links.dup
          through = links.pop.inverse

          links.reverse_each do |relationship|
            inverse = relationship.inverse

            through = self.class.new(
              inverse.name,
              inverse.child_model,
              inverse.parent_model,
              inverse.options.merge(:through => through)
            )
          end

          options.only(*OPTIONS - [ :min, :max ]).update(
            :through    => through,
            :child_key  => options[:parent_key],
            :parent_key => options[:child_key],
            :inverse    => self
          )
        end

        # Loads association targets and sets resulting value on
        # given source resource
        #
        # @param [Resource] source
        #   the source resource for the association
        #
        # @return [undefined]
        #
        # @api private
        def lazy_load(source)
          # FIXME: delegate to super once SEL is enabled
          set!(source, collection_for(source))
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
        # Remove every Resource in the m:m Collection from the repository
        #
        # This performs a deletion of each Resource in the Collection from
        # the repository and clears the Collection.
        #
        # @return [Boolean]
        #   true if the resources were successfully destroyed
        #
        # @api public
        def destroy
          assert_source_saved 'The source must be saved before mass-deleting the collection'

          # make sure the records are loaded so they can be found when
          # the intermediaries are removed
          lazy_load

          unless intermediaries.destroy
            return false
          end

          super
        end

        # Remove every Resource in the m:m Collection from the repository, bypassing validation
        #
        # This performs a deletion of each Resource in the Collection from
        # the repository and clears the Collection while skipping
        # validation.
        #
        # @return [Boolean]
        #   true if the resources were successfully destroyed
        #
        # @api public
        def destroy!
          assert_source_saved 'The source must be saved before mass-deleting the collection'

          # make sure the records are loaded so they can be found when
          # the intermediaries are removed
          lazy_load

          unless intermediaries.destroy!
            return false
          end

          super
        end

        # Return the intermediaries between the source and the targets
        #
        # @return [Collection]
        #   the intermediary collection
        #
        # @api public
        def intermediaries
          return @intermediaries if @intermediaries

          intermediaries = if through.loaded?(source)
            through.get!(source)
          else
            through.set!(source, through.collection_for(source))
          end

          scoped = intermediaries.all(via => self)

          @intermediaries = scoped.query == intermediaries.query ? intermediaries : scoped
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
        def _save(safe)
          if @removed.any?
            # delete only intermediaries linked to the removed targets
            removed_intermediaries = intermediaries.all(via => @removed).each do |resource|
              intermediaries.delete(resource)
            end

            return false unless removed_intermediaries.send(safe ? :destroy : :destroy!)
          end

          if via.respond_to?(:resource_for)
            super
            loaded_entries.all? { |resource| create_intermediary(safe, via => resource) }
          else
            if intermediary = create_intermediary(safe)
              inverse = via.inverse
              loaded_entries.each { |resource| inverse.set(resource, intermediary) }
            end

            super
          end
        end

        # TODO: document
        # @api private
        def create_intermediary(safe, attributes = {})
          collection = intermediaries

          return unless collection.send(safe ? :save : :save!)

          intermediary = collection.first(attributes) ||
                         collection.send(safe ? :create : :create!, attributes)

          return intermediary if intermediary.saved?
        end

        # TODO: document
        # @api private
        def through
          relationship.through
        end

        # TODO: document
        # @api private
        def via
          relationship.via
        end

        # TODO: document
        # @api private
        def inverse_set(*)
          # do nothing
        end
      end # class Collection
    end # module ManyToMany
  end # module Associations
end # module DataMapper
