module DataMapper
  module Adapters
      
    class AbstractAdapter
  
      # Instantiate an Adapter by passing it a DataMapper::Repository
      # connection string for configuration.
      def initialize(uri)
        @uri = uri
      end
      
      def create(database_context, instance)
        raise NotImplementedError.new
      end
      
      def read(database_context, klass, *keys)
        raise NotImplementedError.new
      end
      
      def update(database_context, instance)
        raise NotImplementedError.new
      end
      
      def delete(instance_or_klass, options = nil)
        raise NotImplementedError.new
      end
      
      def save(database_context, instance)
        if instance.new_record?
          create(database_context, instance)
        else
          update(database_context, instance)
        end
      end

    end # class AbstractAdapter
    
  end # module Adapters
end # module DataMapper
