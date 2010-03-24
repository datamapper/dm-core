module DataMapper
  module Resource
    class State

      # a persisted resource (abstract)
      class Persisted < State
        def get(subject, *args)
          lazy_load(subject)
          super
        end

      private

        def repository
          @repository ||= resource.instance_variable_get(:@_repository)
        end

        def collection_for_self
          @collection_for_self ||= resource.collection_for_self
        end

        def lazy_load(subject)
          subject.lazy_load(resource)
        end

      end # class Persisted
    end # class State
  end # module Resource
end # module DataMapper
