module DataMapper
  module Associations
    class Relationship

      attr_reader :name, :repository_name

      # +child_model and child_properties refers to the FK, parent_model
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
      def initialize(name, repository_name, child_model, child_properties, parent_model, parent_properties, &loader)
        @name              = name
        @repository_name   = repository_name
        @child_model       = child_model
        @child_properties  = child_properties   # may be nil
        @parent_model      = parent_model
        @parent_properties = parent_properties  # may be nil
        @loader            = loader
      end

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

      def with_child(child_resource, association, &loader)
        association.new(self, child_resource, lambda {
          loader.call(repository(@repository_name), child_key, parent_key, parent_model, child_resource)
        })
      end

      def with_parent(parent_resource, association, &loader)
        association.new(self, parent_resource, lambda {
          loader.call(repository(@repository_name), child_key, parent_key, child_model, parent_resource)
        })
      end

      def attach_parent(child, parent)
        child_key.set(parent && parent_key.get(parent), child)
      end

      def parent_model
        @parent_model.to_class
      end

      def child_model
        @child_model.to_class
      end
    end # class Relationship
  end # module Associations
end # module DataMapper
