module DataMapper
  module Adapters
    class MockAdapter < DataMapper::Adapters::DataObjectsAdapter

      def create(repository, instance)
        instance
      end
      
      def exists?(storage_name)
        true
      end

    end
  end
end
