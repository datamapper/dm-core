require ROOT_DIR + 'lib/data_mapper/adapters/data_objects_adapter'

module DataMapper
  module Adapters
    class MockAdapter < DataMapper::Adapters::DataObjectsAdapter

      def create(repository, instance)
        instance
      end

    end
  end
end
