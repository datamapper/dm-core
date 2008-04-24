module DataMapper
  module Adapters
    class MockAdapter < DataMapper::Adapters::DataObjectsAdapter

      def create(repository, instance)
        instance
      end

    end
  end
end
