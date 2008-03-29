module DataMapper
  module Associations
    class Relationship

      attr_reader :name, :repository_name

      # +source+ is the FK, +target+ is the PK. Please refer to:
      # http://edocs.bea.com/kodo/docs41/full/html/jdo_overview_mapping_join.html
      # I wash my hands of it!
      #
      # TODO: should repository_name be removed? it would allow relationships across multiple
      # repositories (if query supports it)
      def initialize(name, repository_name, source, target, &loader)

        unless source.is_a?(Array) && source.size == 2
          raise ArgumentError.new("source should be an Array of [resource_name, property_name] but was #{source.inspect}")
        end

        unless target.is_a?(Array) && target.size == 2
          raise ArgumentError.new("target should be an Array of [resource_name, property_name] but was #{target.inspect}")
        end

        @name               = name
        @repository_name    = repository_name
        @source             = source
        @target             = target
        @loader             = loader
      end

      def source
        @source_key || @source_key = begin
          resource = @source.first.to_class
          resource_property_set = resource.properties(@repository_name)

          if @source[1].nil?
            # Default t the target key we're binding to prefixed with the
            # association name.
            target.map do |property|
              property_name = "#{@name}_#{property.name}"
              resource_property_set.detect(property_name) || resource.property(property_name.to_sym, property.type)
            end
          else
            i = 0
            @source[1].map do |property_name|
              target_property = target[i]
              i += 1
              resource_property_set.detect(property_name) || resource.property(property_name, target_property.type)
            end
          end
        end
      end

      def target
        @target_key || @target_key = begin
          resource = @target.first.to_class
          resource_property_set = resource.properties(@repository_name)

          if @target[1].nil?
            resource_property_set.key
          else
            resource_property_set.select(*@target[1])
          end
        end
      end

      def to_set(instance)
        @association_set ||= @loader.call(self, instance)
      end

      def target_resource
        @target.first.to_class
      end

      def source_resource
        @source.first.to_class
      end
    end # class Relationship
  end # module Associations
end # module DataMapper
