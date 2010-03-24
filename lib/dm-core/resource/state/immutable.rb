module DataMapper
  module Resource
    class State

      # a not-persisted/unmodifiable resource
      class Immutable < Transient
        def get(subject, *args)
          unless subject.loaded?(resource)
            raise ImmutableError, 'Immutable resource cannot be lazy loaded'
          end

          subject.get(resource, *args)
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
      end # class Immutable
    end # class State
  end # module Resource
end # module DataMapper
