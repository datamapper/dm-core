module DataMapper
  module Associations
    module ManyToOne #:nodoc:
      # Relationship class with implementation specific
      # to n side of 1 to n association
      class Relationship < Associations::Relationship
        OPTIONS = (superclass::OPTIONS + [ :nullable ]).freeze

        # TODO: document
        # @api semipublic
        alias source_repository_name child_repository_name

        # TODO: document
        # @api semipublic
        alias source_model child_model

        # TODO: document
        # @api semipublic
        alias source_key child_key

        # TODO: document
        # @api semipublic
        alias target_repository_name parent_repository_name

        # TODO: document
        # @api semipublic
        alias target_model parent_model

        # TODO: document
        # @api semipublic
        alias target_key parent_key

        # TODO: document
        # @api semipublic
        def nullable?
          @nullable
        end

        ##
        # Returns a Resoruce for this relationship with a given source
        #
        # @param [Resource] source
        #   A Resource to scope the collection with
        # @param [Query] other_query (optional)
        #   A Query to further scope the collection with
        #
        # @return [Resource]
        #   The resource scoped to the relationship, source and query
        #
        # @api private
        def resource_for(source, other_query = nil)
          query = query_for(source, other_query)

          # TODO: lookup the resource in the Identity Map, and make sure
          # it matches the query criteria, otherwise perform the query

          target_model.first(query)
        end

        # Loads and returns association target (ex.: author) for given source resource
        # (ex.: article)
        #
        # @param  source  [DataMapper::Resource]
        #   Child object (ex.: instance of article)
        # @param  other_query  [DataMapper::Query]
        #   Query options
        #
        # @api semipublic
        def get(source, other_query = nil)
          assert_kind_of 'source', source, source_model

          lazy_load(source) unless loaded?(source)
          resource = get!(source)

          if other_query.nil? || query_for(source, other_query).conditions.matches?(resource)
            resource
          end
        end

        # Sets value of association target (ex.: author) for given source resource
        # (ex.: article)
        #
        # @param source [DataMapper::Resource]
        #   Child object (ex.: instance of article)
        #
        # @param source [DataMapper::Resource]
        #   Parent object (ex.: instance of author)
        #
        # @api semipublic
        def set(source, target)
          assert_kind_of 'source', source, source_model
          assert_kind_of 'target', target, target_model, NilClass

          source_key.set(source, target.nil? ? [] : target_key.get(target))
          set!(source, target)
        end

        private

        # Initializes the relationship, always using max cardinality of 1.
        #
        # @api semipublic
        def initialize(name, source_model, target_model, options = {})
          @nullable      = options.fetch(:nullable, false)
          target_model ||= Extlib::Inflection.camelize(name)
          options        = { :min => @nullable ? 0 : 1, :max => 1 }.update(options)
          super
        end

        def child_key_options(*)
          super.merge(:nullable => nullable?)
        end

        # Dynamically defines reader method for source side of association
        # (for instance, method article for model Paragraph)
        #
        # @api semipublic
        def create_reader
          return if source_model.resource_method_defined?(name.to_s)

          source_model.class_eval <<-RUBY, __FILE__, __LINE__ + 1
            public  # TODO: make this configurable

            # FIXME: if the writer is used, caching nil in the ivar
            # and then the FK(s) are set, the cache in the writer should
            # be cleared.

            def #{name}(query = nil)                          # def article(query = nil)
              relationships[#{name.inspect}].get(self, query) #   relationships["article"].get(self, query)
            end                                               # end
          RUBY
        end

        # Dynamically defines writer method for source side of association
        # (for instance, method article= for model Paragraph)
        #
        # @api semipublic
        def create_writer
          writer_name = "#{name}="

          return if source_model.resource_method_defined?(writer_name)

          source_model.class_eval <<-RUBY, __FILE__, __LINE__ + 1
            public  # TODO: make this configurable
            def #{writer_name}(target)                         # def article=(target)
              relationships[#{name.inspect}].set(self, target) #   relationships["article"].set(self, target)
            end                                                # end
          RUBY
        end

        # Loads association target and sets resulting value on
        # given source resource
        #
        # @api private
        def lazy_load(source)
          return unless source_key.get(source).all?

          # SEL: load all related resources in the source collection
          if source.saved? && source.collection.size > 1
            source.collection.send(name)
          end

          unless loaded?(source)
            set!(source, resource_for(source))
          end
        end

        # Returns the inverse relationship class
        #
        # @api private
        def inverse_class
          OneToMany::Relationship
        end

        # Returns the inverse relationship name
        #
        # @api private
        def inverse_name
          Extlib::Inflection.underscore(Extlib::Inflection.demodulize(source_model.name)).pluralize
        end

        ##
        # Prefix used to build name of default child key
        #
        # @return [Symbol]
        #   The name to prefix the default child key
        #
        # @api semipublic
        def property_prefix
          name
        end
      end # class Relationship
    end # module ManyToOne
  end # module Associations
end # module DataMapper
