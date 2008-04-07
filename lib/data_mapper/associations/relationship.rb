module DataMapper
  module Associations
    class Relationship

      attr_reader :name, :repository_name

      # +child+ is the FK, +parent+ is the PK. Please refer to:
      # http://edocs.bea.com/kodo/docs41/full/html/jdo_overview_mapping_join.html
      # I wash my hands of it!
      #
      # TODO: should repository_name be removed? it would allow relationships across multiple
      # repositories (if query supports it)

      # XXX: why not break up child and parent arguments so the method definition becomes:
      #   initialize(name, repository_name, child_model, child_key, parent_model, parent_key, &loader)
      # The *_key arguments could be Arrays of symbols or a PropertySet object
      def initialize(name, repository_name, child, parent, &loader)

        unless child.is_a?(Array) && child.size == 2
          raise ArgumentError.new("child should be an Array of [model_name, property_name] but was #{child.inspect}")
        end

        unless parent.is_a?(Array) && parent.size == 2
          raise ArgumentError.new("parent should be an Array of [model_name, property_name] but was #{parent.inspect}")
        end

        @name               = name
        @repository_name    = repository_name
        @child              = child
        @parent             = parent
        @loader             = loader
      end

      def child_key      
        @child_key ||= begin
          child_key        = PropertySet.new
          model_properties = child_model.properties(@repository_name)
          parent_keys      = parent_key.to_a

          if child_property_names
            child_property_names.zip(parent_keys).each do |property_name,parent_property|
              child_key << (model_properties[property_name] || child_model.property(property_name, parent_property.type))
            end
          else
            # Default to the parent key we're binding to prefixed with the
            # association name.
            parent_key.each do |property|
              property_name = "#{@name}_#{property.name}"
              child_key << (model_properties[property_name] || child_model.property(property_name.to_sym, property.type))
            end
          end

          child_key
        end
      end

      def parent_key
        @parent_key ||= begin
          parent_key       = PropertySet.new
          model_properties = parent_model.properties(@repository_name)

          keys = if parent_property_names
            model_properties.slice(*parent_property_names)
          else
            model_properties.key
          end

          parent_key.add(*keys)
        end
      end

      def with_child(child_inst, association, &loader)
        association.new(self, child_inst, lambda {
          loader.call(repository(@repository_name), child_key, parent_key, parent_model, child_inst)
        })
      end

      def with_parent(parent_inst, association, &loader)
        association.new(self, parent_inst, lambda {
          loader.call(repository(@repository_name), child_key, parent_key, child_model, parent_inst)
        })
      end

      def attach_parent(child, parent)
        child_key.set(parent && parent_key.get(parent), child)
      end

      def parent_model
        @parent.at(0).to_class
      end

      def child_model
        @child.at(0).to_class
      end

      private

      def child_property_names
        @child.at(1)
      end

      def parent_property_names
        @parent.at(1)
      end
    end # class Relationship
  end # module Associations
end # module DataMapper
