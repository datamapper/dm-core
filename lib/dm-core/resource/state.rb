module DataMapper
  module Resource

    # the state of the resource (abstract)
    class State

      def initialize(resource)
        @resource = resource
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

      def eql?(other)
        instance_of?(other.class) &&
        hash == other.hash
      end

      def ==(other)
        self.class <=> other.class &&
        hash == other.hash
      end

      def hash
        resource.object_id.hash
      end

    private

      attr_reader :resource

      def model
        @model ||= resource.model
      end

      def properties
        @properties ||= model.properties(repository.name)
      end

      def relationships
        @relationships ||= model.relationships(repository.name).values
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

      def reset_original_attributes
        original_attributes.clear
      end

    end # class State
  end # module Resource
end # module DataMapper
