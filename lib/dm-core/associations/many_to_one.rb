module DataMapper
  module Associations
    module ManyToOne #:nodoc:
      # Relationship class with implementation specific
      # to n side of 1 to n association
      class Relationship < Associations::Relationship
        OPTIONS = superclass::OPTIONS.dup << :nullable

        # TODO: document
        # @api semipublic
        alias source_repository_name child_repository_name

        # TODO: document
        # @api semipublic
        alias source_model child_model

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

        # Returns a set of keys that identify child model
        #
        # @return   [DataMapper::PropertySet]  a set of properties that identify child model
        # @api private
        def child_key
          return @child_key if defined?(@child_key)

          repository_name = child_repository_name || parent_repository_name
          properties      = child_model.properties(repository_name)

          child_key = parent_key.zip(@child_properties || []).map do |parent_property, property_name|
            property_name ||= "#{name}_#{parent_property.name}".to_sym

            properties[property_name] || begin
              # create the property within the correct repository
              DataMapper.repository(repository_name) do
                type = parent_property.send(parent_property.type == DataMapper::Types::Boolean ? :type : :primitive)
                child_model.property(property_name, type, child_key_options(parent_property))
              end
            end
          end

          @child_key = properties.class.new(child_key).freeze
        end

        # TODO: document
        # @api semipublic
        alias source_key child_key

        # Returns a Resource for this relationship with a given source
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
          assert_kind_of 'target', target, target_model, Hash, NilClass

          if target.kind_of?(Hash)
            target = target_model.new(target)
          end

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

        # Loads association target and sets resulting value on
        # given source resource
        #
        # @param [Resource] source
        #   the source resource for the association
        #
        # @return [undefined]
        #
        # @api private
        def lazy_load(source)
          return unless source_key.get(source).all?

          # SEL: load all related resources in the source collection
          if source.saved? && source.collection.size > 1
            eager_load(source.collection)
          end

          unless loaded?(source)
            set!(source, resource_for(source))
          end
        end

        # Sets the association targets in the resource
        #
        # @param [Resource] source
        #   the source to set
        # @param [Array(Resource)] targets
        #   the target resource for the association
        # @param [Query, Hash] query
        #   not used
        #
        # @return [undefined]
        #
        # @api private
        def eager_load_targets(source, targets, query)
          set(source, targets.first)
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
          super || Extlib::Inflection.underscore(Extlib::Inflection.demodulize(source_model.name)).pluralize.to_sym
        end

        # TODO: document
        # @api private
        def child_key_options(parent_property)
          options = parent_property.options.only(:length, :precision, :scale).update(:index => name, :nullable => nullable?)

          if parent_property.primitive == Integer && parent_property.min && parent_property.max
            options.update(:min => parent_property.min, :max => parent_property.max)
          end

          options
        end

        # TODO: document
        # @api private
        def child_properties
          child_key.map { |property| property.name }
        end
      end # class Relationship
    end # module ManyToOne
  end # module Associations
end # module DataMapper
