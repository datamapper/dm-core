module DataMapper
  module Adapters
      
    class AbstractAdapter
  
      # Instantiate an Adapter by passing it a DataMapper::Repository
      # connection string for configuration.
      def initialize(uri)
        @uri = uri
      end
      
      def create(repository, instance)
        raise NotImplementedError.new
      end
      
      def read(repository, klass, *keys)
        raise NotImplementedError.new
      end
      
      # This may be "good enough" for most adapters.
      def first(repository, klass, query)
        all(repository, klass, query.merge(:limit => 1)).first
      end
      
      # +query+ would be an "options-hash". I'm just tired of
      # writing "options". It's a dumb name for an arg. ;-)
      def all(repository, klass, query)
        raise NotImplementedError.new
      end
      
      def update(repository, instance)
        raise NotImplementedError.new
      end
      
      def delete(repository, options = nil)
        raise NotImplementedError.new
      end
      
      def save(repository, instance)
        if instance.new_record?
          create(repository, instance)
        else
          update(repository, instance)
        end
      end

    end # class AbstractAdapter
    
  end # module Adapters
end # module DataMapper
