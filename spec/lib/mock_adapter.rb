module DataMapper
  module Adapters
    class MockAdapter < DataMapper::Adapters::DataObjectsAdapter

      def create(repository, instance)
        instance
      end

    end
  end
end

module DataObjects
  module Mock
    
    def self.logger
    end
    
    def self.logger=(value)
    end
    
  end
end
