module DataMapper
  module Associations
    class Relationship
      OPTIONS = [ :class_name, :child_key, :parent_key, :min, :max, :through ]

      attr_reader :name, :repository_name, :options, :query

      def child_key
        @child_key ||= begin
          model_properties = child_model.properties(repository_name)

          child_key = parent_key.zip(@child_properties || []).map do |parent_property,property_name|
            # TODO: use something similar to DM::NamingConventions to determine the property name
            property_name ||= "#{name}_#{parent_property.name}".to_sym

            model_properties[property_name] || DataMapper.repository(repository_name) do
              attributes = {}
              [ :length, :scale, :precision ].each do |attribute|
                attributes[attribute] = parent_property.send(attribute)
              end
              child_model.property(property_name, parent_property.type, attributes)
            end
          end

          PropertySet.new(child_key)
        end
      end

      def parent_key
        @parent_key ||= begin
          parent_key = if @parent_properties
            parent_model.properties(repository_name).slice(*@parent_properties)
          else
            parent_model.key(repository_name)
          end

          PropertySet.new(parent_key)
        end
      end

      def get_children(parent, options = {})
        bind_values = parent_key.get(parent)
        query = child_key.to_query(bind_values)

        DataMapper.repository(repository_name) do
          child_model.all(@query.merge(options).merge(query))
        end
      end

      def get_parent(child)
        bind_values = child_key.get(child)
        return nil if bind_values.any? { |bind_value| bind_value.nil? }
        query = parent_key.to_query(bind_values)

        DataMapper.repository(repository_name) do
          parent_model.first(@query.merge(query))
        end
      end

      def attach_parent(child, parent)
        child_key.set(child, parent && parent_key.get(parent))
      end

      def parent_model
        find_const(@parent_model_name)
      end

      def child_model
        find_const(@child_model_name)
      end

      private

      # +child_model_name and child_properties refers to the FK, parent_model_name
      # and parent_properties refer to the PK.  For more information:
      # http://edocs.bea.com/kodo/docs41/full/html/jdo_overview_mapping_join.html
      # I wash my hands of it!
      def initialize(name, repository_name, child_model_name, parent_model_name, options = {}, &loader)
        raise ArgumentError, "+name+ should be a Symbol, but was #{name.class}", caller                         unless Symbol === name
        raise ArgumentError, "+repository_name+ must be a Symbol, but was #{repository_name.class}", caller     unless Symbol === repository_name
        raise ArgumentError, "+child_model_name+ must be a String, but was #{child_model_name.class}", caller   unless String === child_model_name
        raise ArgumentError, "+parent_model_name+ must be a String, but was #{parent_model_name.class}", caller unless String === parent_model_name

        if child_properties = options[:child_key]
          raise ArgumentError, "+options[:child_key]+ must be an Array or nil, but was #{child_properties.class}", caller unless Array === child_properties
        end

        if parent_properties = options[:parent_key]
          raise ArgumentError, "+parent_properties+ must be an Array or nil, but was #{parent_properties.class}", caller unless Array === parent_properties
        end

        @name              = name
        @repository_name   = repository_name
        @child_model_name  = child_model_name
        @child_properties  = child_properties   # may be nil
        @query             = options.reject { |k,v| OPTIONS.include?(k) }
        @parent_model_name = parent_model_name
        @parent_properties = parent_properties  # may be nil
        @options           = options
        @loader            = loader
      end
    end # class Relationship
  end # module Associations
end # module DataMapper
