module DataMapper
  module Adapters
      
    class AbstractAdapter
  
      # Instantiate an Adapter by passing it a DataMapper::Repository
      # object for configuration.
      def initialize(uri)
        @uri = uri
      end
      
      def index_path
        @configuration.index_path
      end
      
      def delete(instance_or_klass, options = nil)
        raise NotImplementedError.new
      end
      
      def save(database_context, instance)
        raise NotImplementedError.new
      end
      
      def load(database_context, klass, options)
        raise NotImplementedError.new
      end
      
      def get(database_context, klass, *keys)
        raise NotImplementedError.new
      end
      
    end # class AbstractAdapter
    
  end # module Adapters
end # module DataMapper
