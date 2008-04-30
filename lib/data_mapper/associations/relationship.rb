module DataMapper
  module Associations
    class Relationship

      attr_reader :name, :repository_name, :options

      def child_key
        @child_key ||= begin
          model_properties = child_model.properties(@repository_name)

          child_key = parent_key.zip(@child_properties || []).map do |parent_property,property_name|
            # TODO: use something similar to DM::NamingConventions to determine the property name
            property_name ||= "#{@name}_#{parent_property.name}".to_sym
            model_properties[property_name] || child_model.property(property_name, parent_property.type)
          end

          PropertySet.new(child_key)
        end
      end

      def parent_key
        @parent_key ||= begin
          model_properties = parent_model.properties(@repository_name)

          parent_key = if @parent_properties
            model_properties.slice(*@parent_properties)
          else
            model_properties.key
          end

          PropertySet.new(parent_key)
        end
      end


      def to_child_query(parent)
        [child_model, child_key.to_query(parent_key.get(parent))]
      end

      def with_child(child_resource, association, &loader)
        association.new(self, child_resource) do
          yield repository(@repository_name), child_key, parent_key, parent_model, child_resource
        end
      end

      def attach_parent(child, parent)
        child_key.set(child, parent && parent_key.get(parent))
      end

      def parent_model
        @parent_model_name.to_class
      end

      def child_model
        @child_model_name.to_class
      end

      private

      # +child_model_name and child_properties refers to the FK, parent_model_name
      # and parent_properties refer to the PK.  For more information:
      # http://edocs.bea.com/kodo/docs41/full/html/jdo_overview_mapping_join.html
      # I wash my hands of it!

      # FIXME: should we replace child_* and parent_* arguments with two
      # Arrays of Property objects?  This would allow syntax like:
      #
      #   belongs_to = DataMapper::Associations::Relationship.new(
      #     :manufacturer,
      #     :relationship_spec,
      #     Vehicle.properties.slice(:manufacturer_id)
      #     Manufacturer.properties.slice(:id)
      #   )
      def initialize(name,options, repository_name, child_model_name, child_properties, parent_model_name, parent_properties, &loader)
        raise ArgumentError, "+name+ should be a Symbol, but was #{name.class}", caller                                unless Symbol === name
        raise ArgumentError, "+repository_name+ must be a Symbol, but was #{repository_name.class}", caller            unless Symbol === repository_name
        raise ArgumentError, "+child_model_name+ must be a String, but was #{child_model_name.class}", caller          unless String === child_model_name
        raise ArgumentError, "+child_properties+ must be an Array or nil, but was #{child_properties.class}", caller   unless Array  === child_properties || child_properties.nil?
        raise ArgumentError, "+parent_model_name+ must be a String, but was #{parent_model_name.class}", caller        unless String === parent_model_name
        raise ArgumentError, "+parent_properties+ must be an Array or nil, but was #{parent_properties.class}", caller unless Array  === parent_properties || parent_properties.nil?

        @name              = name
        @options           = options
        @repository_name   = repository_name
        @child_model_name  = child_model_name
        @child_properties  = child_properties   # may be nil
        @parent_model_name = parent_model_name
        @parent_properties = parent_properties  # may be nil
        @loader            = loader
      end
    end # class Relationship
  end # module Associations
end # module DataMapper
