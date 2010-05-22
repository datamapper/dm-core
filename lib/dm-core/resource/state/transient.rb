module DataMapper
  module Resource
    class State

      # a not-persisted/modifiable resource
      class Transient < State
        def get(subject, *args)
          set_default_value(subject)
          super
        end

        def set(subject, value)
          track(subject)
          super
        end

        def delete
          self
        end

        def commit
          set_child_keys
          set_default_values
          return self unless valid_attributes?
          create_resource
          set_repository
          add_to_identity_map
          Clean.new(resource)
        end

        def rollback
          self
        end

        def original_attributes
          @original_attributes ||= {}
        end

      private

        def repository
          @repository ||= model.repository
        end

        def set_default_values
          (properties | relationships).each do |subject|
            set_default_value(subject)
          end
        end

        def set_default_value(subject)
          return if subject.loaded?(resource) || !subject.default?
          set(subject, subject.default_for(resource))
        end

        def track(subject)
          original_attributes[subject] = nil
        end

        def create_resource
          repository.create([ resource ])
        end

        def set_repository
          resource.instance_variable_set(:@_repository, repository)
        end

        def valid_attributes?
          properties.all? do |property|
            value = get(property)
            property.serial? && value.nil? || property.valid?(value)
          end
        end

      end # class Transient
    end # class State
  end # module Resource
end # module DataMapper
