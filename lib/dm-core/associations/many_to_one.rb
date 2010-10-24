module DataMapper
  module Associations
    module ManyToOne #:nodoc:
      # Relationship class with implementation specific
      # to n side of 1 to n association
      class Relationship < Associations::Relationship
        OPTIONS = superclass::OPTIONS.dup << :required << :key

        # @api semipublic
        alias_method :source_repository_name, :child_repository_name

        # @api semipublic
        alias_method :source_model, :child_model

        # @api semipublic
        alias_method :target_repository_name, :parent_repository_name

        # @api semipublic
        alias_method :target_model, :parent_model

        # @api semipublic
        alias_method :target_key, :parent_key

        # @api semipublic
        def required?
          @required
        end

        # @api semipublic
        def key?
          @key
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
                model.property(property_name, parent_property.to_child_key, child_key_options(parent_property))
              end
            end
          end

          @child_key = properties.class.new(child_key).freeze
        end

        # @api semipublic
        alias_method :source_key, :child_key

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

          # If the target key is equal to the model key, we can use the
          # Model#get so the IdentityMap is used
          if target_key == target_model.key
            target = target_model.get(*source_key.get!(source))
            if query.conditions.matches?(target)
              target
            else
              nil
            end
          else
            target_model.first(query)
          end
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
        def get(source, query = nil)
          lazy_load(source)
          collection = get_collection(source)
          collection.first(query) if collection
        end

        def get_collection(source)
          resource = get!(source)
          resource.collection_for_self if resource
        end

        # Sets value of association target (ex.: author) for given source resource
        # (ex.: article)
        #
        # @param source [DataMapper::Resource]
        #   Child object (ex.: instance of article)
        #
        # @param target [DataMapper::Resource]
        #   Parent object (ex.: instance of author)
        #
        # @api semipublic
        def set(source, target)
          target = typecast(target)
          source_key.set(source, target_key.get(target))
          set!(source, target)
        end

        # @api semipublic
        def default_for(source)
          typecast(super)
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
          return if loaded?(source) || !valid_source?(source)

          # SEL: load all related resources in the source collection
          collection = source.collection
          if source.saved? && collection.size > 1
            eager_load(collection)
          end

          unless loaded?(source)
            set!(source, resource_for(source))
          end
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
          @key           = options.fetch(:key,      false)
          target_model ||= DataMapper::Inflector.camelize(name)
          options        = { :min => @required ? 1 : 0, :max => 1 }.update(options)
          super
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

        # @api private
        def typecast(target)
          if target.kind_of?(Hash)
            target_model.new(target)
          else
            target
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
          super || DataMapper::Inflector.underscore(DataMapper::Inflector.demodulize(source_model.name)).pluralize.to_sym
        end

        # @api private
        def child_key_options(parent_property)
          options = parent_property.options.only(:length, :precision, :scale).update(
            :index    => name,
            :required => required?,
            :key      => key?
          )

          if parent_property.primitive == Integer
            min = parent_property.min
            max = parent_property.max

            options.update(:min => min, :max => max) if min && max
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
