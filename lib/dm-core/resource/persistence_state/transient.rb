module DataMapper
  module Resource
    class PersistenceState

      # a not-persisted/modifiable resource
      class Transient < PersistenceState
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
          assert_valid_attributes!
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

        def assert_valid_attributes!
          properties.each do |property|
            value = get(property)
            unless property.serial? && value.nil? || property.valid?(value)
              raise "property #{property.name} is invalid in transient state for value: #{value.inspect}"
            end
          end
        end

      end # class Transient
    end # class PersistenceState
  end # module Resource
end # module DataMapper
