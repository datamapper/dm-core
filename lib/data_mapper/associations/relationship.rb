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
      def initialize(name, repository_name, child, parent, &loader)

        unless child.is_a?(Array) && child.size == 2
          raise ArgumentError.new("child should be an Array of [resource_name, property_name] but was #{child.inspect}")
        end

        unless parent.is_a?(Array) && parent.size == 2
          raise ArgumentError.new("parent should be an Array of [resource_name, property_name] but was #{parent.inspect}")
        end

        @name               = name
        @repository_name    = repository_name
        @child              = child
        @parent             = parent
        @loader             = loader
      end

      def child_key      
        @child_key ||= begin
          resource = @child.first.to_class
          resource_property_set = resource.properties(@repository_name)

          if @child[1].nil?
            # Default t the parent key we're binding to prefixed with the
            # association name.
            PropertySet.new.concat(parent_key.map do |property|
              property_name = "#{@name}_#{property.name}"
              resource_property_set.detect(property_name) || resource.property(property_name.to_sym, property.type)
            end)
          else
            i = 0
            PropertySet.new.concat(@child[1].map do |property_name|
              parent_property = parent_key[i]
              i += 1
              resource_property_set.detect(property_name) || resource.property(property_name, parent_property.type)
            end)
          end
        end
      end

      def parent_key
        @parent_key ||= begin
          resource = @parent.first.to_class
          resource_property_set = resource.properties(@repository_name)

          if @parent[1].nil?
            PropertySet.new.concat(resource_property_set.key)
          else
            PropertySet.new.concat(resource_property_set.select(*@parent[1]))
          end
        end
      end

      def with_child(child_inst, association, &loader)
        association.new(self, child_inst, lambda {
          loader.call(repository(@repository_name), child_key, parent_key, parent_resource, child_inst)
        })
      end

      def with_parent(parent_inst, association, &loader)
        association.new(self, parent_inst, lambda {
          loader.call(repository(@repository_name), child_key, parent_key, child_resource, parent_inst)
        })
      end

      def attach_parent(child, parent)
        self.child_key.set(parent && self.parent_key.value(parent), child)
      end

      def parent_resource
        @parent.first.to_class
      end

      def child_resource
        @child.first.to_class
      end

      def repository_name
        @repository_name
      end
    end # class Relationship
  end # module Associations
end # module DataMapper
