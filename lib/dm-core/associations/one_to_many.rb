module DataMapper
  module Associations
    module OneToMany #:nodoc:
      class Relationship < Associations::Relationship
        # TODO: document
        # @api semipublic
        alias target_repository_name child_repository_name

        # TODO: document
        # @api semipublic
        alias target_model child_model

        # TODO: document
        # @api semipublic
        alias target_key child_key

        # TODO: document
        # @api semipublic
        alias source_repository_name parent_repository_name

        # TODO: document
        # @api semipublic
        alias source_model parent_model

        # TODO: document
        # @api semipublic
        alias source_key parent_key

        # Creates and returns Query instance that fetches
        # target resource(s) (ex.: articles) for given target resource (ex.: author)
        #
        # @api semipublic
        def query_for(source, other_query = nil)
          query = self.query.merge(source_scope(source))
          query.update(other_query) if other_query

          Query.new(DataMapper.repository(target_repository_name), target_model, query)
        end

        ##
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

          collection
        end

        # Loads and returns association targets (ex.: articles) for given source resource
        # (ex.: author)
        #
        # @api semipublic
        def get(source, other_query = nil)
          assert_kind_of 'source', source, source_model

          lazy_load(source) unless loaded?(source)
          get!(source).all(other_query)
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

        # TODO: document
        # @api semipublic
        def initialize(name, target_model, source_model, options = {})
          target_model ||= Extlib::Inflection.camelize(name.to_s.singular).freeze
          super
        end

        # Dynamically defines reader method for source side of association
        # (for instance, method paragraphs for model Article)
        #
        # @api semipublic
        def create_reader
          return if source_model.instance_methods(false).any? { |m| m.to_sym == name }

          source_model.class_eval <<-RUBY, __FILE__, __LINE__ + 1
            def #{name}(query = nil)                           # def paragraphs(query = nil)
              relationships[#{name.inspect}].get(self, query)  #   relationships[:paragraphs].get(self, query)
            end                                                # end
          RUBY
        end

        # Dynamically defines reader method for source side of association
        # (for instance, method paragraphs= for model Article)
        #
        # @api semipublic
        def create_writer
          writer_name = "#{name}=".to_sym

          return if source_model.instance_methods(false).any? { |m| m.to_sym == writer_name }

          source_model.class_eval <<-RUBY, __FILE__, __LINE__ + 1
            def #{writer_name}(targets)                          # def paragraphs=(targets)
              relationships[#{name.inspect}].set(self, targets)  #   relationships[:paragraphs].set(self, targets)
            end                                                  # end
          RUBY
        end

        # Loads association targets and sets resulting value on
        # given source resource
        #
        # @api private
        def lazy_load(source)
          # TODO: if the collection is not loaded, then use a subquery
          # to load it.

          if source.saved? && source.collection.size > 1
            # SEL: load all related resources in the source collection
            source.collection.send(name)
          else
            set!(source, collection_for(source))
          end
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
          Extlib::Inflection.underscore(source_model.name)
        end

        ##
        # Prefix used to build name of default child key
        #
        # @return [Symbol]
        #   The name to prefix the default child key
        #
        # @api semipublic
        def property_prefix
          # TODO: try to use the inverse relationship name if possible
          Extlib::Inflection.underscore(Extlib::Inflection.demodulize(parent_model.base_model.name)).to_sym
        end
      end # class Relationship

      class Collection < DataMapper::Collection

        # TODO: document
        # @api private
        attr_accessor :relationship

        # TODO: document
        # @api private
        attr_accessor :source

        # TODO: document
        # @api public
        def reload(*)
          assert_source_saved 'The source must be saved before reloading the collection'
          super
        end

        ##
        # Access Collection#replace directly
        #
        # @api private
        alias collection_replace replace
        private :collection_replace

        # TODO: document
        # @api public
        def replace(*)
          lazy_load if source.saved?  # lazy load so that targets are always orphaned
          super
        end

        # TODO: document
        # @api public
        def clear
          lazy_load if source.saved?  # lazy load so that targets are always orphaned
          super
        end

        # TODO: document
        # @api public
        def create(*)
          assert_source_saved 'The source must be saved before creating a Resource'
          super
        end

        # TODO: document
        # @api public
        def update(*)
          assert_source_saved 'The source must be saved before mass-updating the collection'
          super
        end

        # TODO: document
        # @api public
        def update!(*)
          assert_source_saved 'The source must be saved before mass-updating the collection without validation'
          super
        end

        # TODO: document
        # @api public
        def save
          assert_source_saved 'The source must be saved before saving the collection'

          # remove reference to source in orphans
          @orphans.each { |r| r.save }

          super
        end

        # TODO: document
        # @api public
        def destroy
          assert_source_saved 'The source must be saved before mass-deleting the collection'
          super
        end

        # TODO: document
        # @api public
        def destroy!
          assert_source_saved 'The source must be saved before mass-deleting the collection without validation'
          super
        end

        private

        # TODO: document
        # @api private
        def lazy_load
          if source.saved? || loaded?
            super
          else
            mark_loaded

            # TODO: DRY this up with LazyArray
            @array.unshift(*head)
            @array.concat(tail)

            @head = @tail = nil
            @reapers.each { |r| @array.delete_if(&r) } if @reapers
            @array.freeze if frozen?

            self
          end
        end

        # TODO: document
        # @api private
        def new_collection(query, resources = nil, &block)
          collection = self.class.new(query, &block)

          collection.relationship = relationship
          collection.source       = source

          resources ||= filter(query) if loaded?

          # set the resources after the relationship and source are set
          if resources
            collection.send(:collection_replace, resources)
          end

          collection
        end

        # TODO: document
        # @api private
        def relate_resource(resource)
          return if resource.nil?

          if relationship.source_key.loaded?(source)
            relationship.inverse.set(resource, source)
          end

          super
        end

        # TODO: document
        # @api private
        def orphan_resource(resource)
          return if resource.nil?

          # only orphan a resource if it could have been related previously
          if !resource.frozen? && relationship.source_key.loaded?(source)
            relationship.inverse.set(resource, nil)
          end

          super
        end

        # TODO: document
        # @api private
        def assert_source_saved(message)
          unless source.saved? || loaded?
            raise UnsavedParentError, message
          end
        end
      end # class Collection
    end # module OneToMany
  end # module Associations
end # module DataMapper
