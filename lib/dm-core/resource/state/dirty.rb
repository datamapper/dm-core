module DataMapper
  module Resource
    class State

      # a persisted/dirty resource
      class Dirty < Persisted
        def set(subject, value)
          track(subject, value)
          super
          original_attributes.empty? ? Clean.new(resource) : self
        end

        def delete
          reset_resource
          Deleted.new(resource)
        end

        def commit
          remove_from_identity_map
          set_child_keys
          return self unless valid_attributes?
          update_resource
          reset_original_attributes
          reset_resource_key
          Clean.new(resource)
        ensure
          add_to_identity_map
        end

        def rollback
          reset_resource
          Clean.new(resource)
        end

        def original_attributes
          @original_attributes ||= {}
        end

      private

        def track(subject, value)
          if original_attributes.key?(subject)
            # stop tracking if the new value is the same as the original
            if original_attributes[subject].eql?(value)
              original_attributes.delete(subject)
            end
          elsif !value.eql?(original = get(subject))
            # track the original value
            original_attributes[subject] = original
          end
        end

        def update_resource
          repository.update(resource.dirty_attributes, collection_for_self)
        end

        def reset_resource
          reset_resource_properties
          reset_resource_relationships
        end

        def reset_resource_key
          resource.instance_eval { remove_instance_variable(:@_key) }
        end

        def reset_resource_properties
          # delete every original attribute after resetting the resource
          original_attributes.delete_if do |property, value|
            property.set!(resource, value)
            true
          end
        end

        def reset_resource_relationships
          relationships.each do |relationship|
            next unless relationship.loaded?(resource)
            # TODO: consider a method in Relationship that can reset the relationship
            resource.instance_eval { remove_instance_variable(relationship.instance_variable_name) }
          end
        end

        def reset_original_attributes
          original_attributes.clear
        end

        def valid_attributes?
          original_attributes.each_key do |property|
            return false if property.kind_of?(Property) && !property.valid?(property.get!(resource))
          end
          true
        end

      end # class Dirty
    end # class State
  end # module Resource
end # module DataMapper
