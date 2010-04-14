module DataMapper
  module Resource
    class State

      # a not-persisted/unmodifiable resource
      class Immutable < State
        def get(subject, *args)
          unless subject.loaded?(resource) || subject.kind_of?(Associations::Relationship)
            raise ImmutableError, 'Immutable resource cannot be lazy loaded'
          end

          super
        end

        def set(subject, value)
          raise ImmutableError, 'Immutable resource cannot be modified'
        end

        def delete
          raise ImmutableError, 'Immutable resource cannot be deleted'
        end

        def commit
          self
        end

        def rollback
          self
        end

      end # class Immutable
    end # class State
  end # module Resource
end # module DataMapper
