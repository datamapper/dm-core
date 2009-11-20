module DataMapper
  module Associations
    module OneToMany #:nodoc:
      class Relationship < Associations::Relationship
        # @api semipublic
        alias target_repository_name child_repository_name

        # @api semipublic
        alias target_model child_model

        # @api semipublic
        alias source_repository_name parent_repository_name

        # @api semipublic
        alias source_model parent_model

        # @api semipublic
        alias source_key parent_key

        # @api semipublic
        def child_key
          inverse.child_key
        end

        # @api semipublic
        alias target_key child_key

        # Returns a Collection for this relationship with a given source
        #
        # @param [Resource] source
        #   A Resource to scope the collection with
        # @param [Query] other_query (optional)
        #   A Query to further scope the collection with
        #
        # @return [Collection]
        #   The collection scoped to the relationship, source and query
        #
        # @api private
        def collection_for(source, other_query = nil)
          query = query_for(source, other_query)

          collection = collection_class.new(query)
          collection.relationship = self
          collection.source       = source

          # make the collection empty if the source is not saved
          collection.replace([]) unless source.saved?

          collection
        end

        # Loads and returns association targets (ex.: articles) for given source resource
        # (ex.: author)
        #
        # @api semipublic
        def get(source, other_query = nil)
          assert_kind_of 'source', source, source_model

          lazy_load(source) unless loaded?(source)

          collection = get!(source)
          other_query.nil? ? collection : collection.all(other_query)
        end

        # Sets value of association targets (ex.: paragraphs) for given source resource
        # (ex.: article)
        #
        # @api semipublic
        def set(source, targets)
          assert_kind_of 'source',  source,  source_model
          assert_kind_of 'targets', targets, Array

          lazy_load(source) unless loaded?(source)

          get!(source).replace(targets)
        end

        private

        # @api semipublic
        def initialize(name, target_model, source_model, options = {})
          target_model ||= Extlib::Inflection.camelize(name.to_s.singular)
          options        = { :min => 0, :max => source_model.n }.update(options)
          super
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
          # SEL: load all related resources in the source collection
          collection = source.collection
          if source.saved? && collection.size > 1
            eager_load(collection)
          end

          unless loaded?(source)
            set!(source, collection_for(source))
          end
        end

        # Sets the association targets in the resource
        #
        # @param [Resource] source
        #   the source to set
        # @param [Array<Resource>] targets
        #   the target collection for the association
        # @param [Query, Hash] query
        #   the query to scope the association with
        #
        # @return [undefined]
        #
        # @api private
        def eager_load_targets(source, targets, query)
          set!(source, collection_for(source, query).set(targets))
        end

        # Returns collection class used by this type of
        # relationship
        #
        # @api private
        def collection_class
          OneToMany::Collection
        end

        # Returns the inverse relationship class
        #
        # @api private
        def inverse_class
          ManyToOne::Relationship
        end

        # Returns the inverse relationship name
        #
        # @api private
        def inverse_name
          super || Extlib::Inflection.underscore(Extlib::Inflection.demodulize(source_model.name)).to_sym
        end

        # @api private
        def child_properties
          super || parent_key.map do |parent_property|
            "#{inverse_name}_#{parent_property.name}".to_sym
          end
        end
      end # class Relationship

      class Collection < DataMapper::Collection
        # @api private
        attr_accessor :relationship

        # @api private
        attr_accessor :source

        # @api public
        def reload(*)
          assert_source_saved 'The source must be saved before reloading the collection'
          super
        end

        # Replace the Resources within the 1:m Collection
        #
        # @param [Enumerable] other
        #   List of other Resources to replace with
        #
        # @return [Collection]
        #   self
        #
        # @api public
        def replace(*)
          lazy_load  # lazy load so that targets are always orphaned
          super
        end

        # Removes all Resources from the 1:m Collection
        #
        # This should remove and orphan each Resource from the 1:m Collection.
        #
        # @return [Collection]
        #   self
        #
        # @api public
        def clear
          lazy_load  # lazy load so that targets are always orphaned
          super
        end

        # Update every Resource in the 1:m Collection
        #
        # @param [Hash] attributes
        #   attributes to update with
        #
        # @return [Boolean]
        #   true if the resources were successfully updated
        #
        # @api public
        def update(*)
          assert_source_saved 'The source must be saved before mass-updating the collection'
          super
        end

        # Update every Resource in the 1:m Collection, bypassing validation
        #
        # @param [Hash] attributes
        #   attributes to update
        #
        # @return [Boolean]
        #   true if the resources were successfully updated
        #
        # @api public
        def update!(*)
          assert_source_saved 'The source must be saved before mass-updating the collection'
          super
        end

        # Remove every Resource in the 1:m Collection from the repository
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
          super
        end

        # Remove every Resource in the 1:m Collection from the repository, bypassing validation
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
          super
        end

        private

        # @api private
        def _create(*)
          assert_source_saved 'The source must be saved before creating a resource'
          super
        end

        # @api private
        def _save(safe)
          assert_source_saved 'The source must be saved before saving the collection'

          # update removed resources to not reference the source
          @removed.all? { |resource| resource.destroyed? || resource.__send__(safe ? :save : :save!) } && super
        end

        # @api private
        def lazy_load
          if source.saved?
            super
          end
        end

        # @api private
        def new_collection(query, resources = nil, &block)
          collection = self.class.new(query, &block)

          collection.relationship = relationship
          collection.source       = source

          resources ||= filter(query) if loaded?

          # set the resources after the relationship and source are set
          if resources
            collection.set(resources)
          end

          collection
        end

        # @api private
        def resource_added(resource)
          resource = initialize_resource(resource)
          inverse_set(resource, source)
          super
        end

        # @api private
        def resource_removed(resource)
          inverse_set(resource, nil)
          super
        end

        # @api private
        def inverse_set(source, target)
          unless source.readonly?
            relationship.inverse.set(source, target)
          end
        end

        # @api private
        def assert_source_saved(message)
          unless source.saved?
            raise UnsavedParentError, message
          end
        end
      end # class Collection
    end # module OneToMany
  end # module Associations
end # module DataMapper
