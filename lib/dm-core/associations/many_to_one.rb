module DataMapper
  module Associations
    module ManyToOne #:nodoc:
      # Relationship class with implementation specific
      # to n side of 1 to n association
      class Relationship < Associations::Relationship
        OPTIONS = superclass::OPTIONS.dup << :required

        # @api semipublic
        alias source_repository_name child_repository_name

        # @api semipublic
        alias source_model child_model

        # @api semipublic
        alias target_repository_name parent_repository_name

        # @api semipublic
        alias target_model parent_model

        # @api semipublic
        alias target_key parent_key

        # @api semipublic
        def required?
          @required
        end

        # @api private
        def nullable?
          klass = self.class
          warn "#{klass}#nullable? is deprecated, use #{klass}#required? instead (#{caller[0]})"
          !required?
        end

        # Returns a set of keys that identify child model
        #
        # @return   [DataMapper::PropertySet]  a set of properties that identify child model
        # @api private
        def child_key
          return @child_key if defined?(@child_key)

          model           = child_model
          repository_name = child_repository_name || parent_repository_name
          properties      = model.properties(repository_name)

          child_key = parent_key.zip(@child_properties || []).map do |parent_property, property_name|
            property_name ||= "#{name}_#{parent_property.name}".to_sym

            properties[property_name] || begin
              # create the property within the correct repository
              DataMapper.repository(repository_name) do
                type = parent_property.send(parent_property.type == DataMapper::Types::Boolean ? :type : :primitive)
                model.property(property_name, type, child_key_options(parent_property))
              end
            end
          end

          @child_key = properties.class.new(child_key).freeze
        end

        # @api semipublic
        alias source_key child_key

        # Returns a hash of conditions that scopes query that fetches
        # target object
        #
        # @return [Hash]
        #   Hash of conditions that scopes query
        #
        # @api private
        def source_scope(source)
          if source.kind_of?(Resource)
            Query.target_conditions(source, source_key, target_key)
          else
            super
          end
        end

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
          target_model = self.target_model

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
          if options.key?(:nullable)
            nullable_options = options.only(:nullable)
            required_options = { :required => !options.delete(:nullable) }
            warn "#{nullable_options.inspect} is deprecated, use #{required_options.inspect} instead (#{caller[2]})"
            options.update(required_options)
          end

          @required      = options.fetch(:required, true)
          target_model ||= Extlib::Inflection.camelize(name)
          options        = { :min => @required ? 1 : 0, :max => 1 }.update(options)
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
          return unless valid_source?(source)

          # SEL: load all related resources in the source collection
          collection = source.collection
          if source.saved? && collection.size > 1
            eager_load(collection)
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

        # @api private
        def child_key_options(parent_property)
          options = parent_property.options.only(:length, :precision, :scale).update(:index => name, :required => required?)

          min = parent_property.min
          max = parent_property.max

          if parent_property.primitive == Integer && min && max
            options.update(:min => min, :max => max)
          end

          options
        end

        # @api private
        def child_properties
          child_key.map { |property| property.name }
        end
      end # class Relationship
    end # module ManyToOne
  end # module Associations
end # module DataMapper
