module DataMapper
  module Resource

    # the state of the resource (abstract)
    class PersistenceState
      extend Equalizer

      equalize :resource

      attr_reader :resource

      def initialize(resource)
        @resource = resource
        @model    = resource.model
      end

      def get(subject, *args)
        subject.get(resource, *args)
      end

      def set(subject, value)
        subject.set(resource, value)
        self
      end

      def delete
        raise NotImplementedError, "#{self.class}#delete should be implemented"
      end

      def commit
        raise NotImplementedError, "#{self.class}#commit should be implemented"
      end

      def rollback
        raise NotImplementedError, "#{self.class}#rollback should be implemented"
      end

    private

      attr_reader :model

      def properties
        @properties ||= model.properties(repository.name)
      end

      def relationships
        @relationships ||= model.relationships(repository.name)
      end

      def identity_map
        @identity_map ||= repository.identity_map(model)
      end

      def remove_from_identity_map
        identity_map.delete(resource.key)
      end

      def add_to_identity_map
        identity_map[resource.key] = resource
      end

      def set_child_keys
        relationships.each do |relationship|
          set_child_key(relationship)
        end
      end

      def set_child_key(relationship)
        return unless relationship.loaded?(resource) && relationship.respond_to?(:resource_for)
        set(relationship, get(relationship))
      end

    end # class PersistenceState
  end # module Resource
end # module DataMapper
