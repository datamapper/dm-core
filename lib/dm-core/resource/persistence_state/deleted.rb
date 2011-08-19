module DataMapper
  module Resource
    class PersistenceState

      # a persisted/deleted resource
      class Deleted < Persisted
        def set(subject, value)
          raise ImmutableDeletedError, 'Deleted resource cannot be modified'
        end

        def delete
          self
        end

        def commit
          delete_resource
          remove_from_identity_map
          Immutable.new(resource)
        end

      private

        def delete_resource
          repository.delete(collection_for_self)
        end

      end # class Deleted
    end # class PersistenceState
  end # module Resource
end # module DataMapper
