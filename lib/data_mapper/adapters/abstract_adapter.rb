module DataMapper
  module Adapters
      
    class AbstractAdapter
  
      # Instantiate an Adapter by passing it a DataMapper::Repository
      # connection string for configuration.
      def initialize(uri)
        @uri = uri
      end
      
      attr_accessor :resource_naming_convention

      # Methods dealing with a single instance object
      def create(repository, instance)
        raise NotImplementedError.new
      end
      
      def read(repository, resource, key)
        raise NotImplementedError.new
      end
      
      def update(repository, instance)
        raise NotImplementedError.new
      end
      
      def delete(repository, instance)
        raise NotImplementedError.new
      end
      
      def save(repository, instance)
        if instance.new_record?
          create(repository, instance)
        else
          update(repository, instance)
        end
      end

      # Methods dealing with locating a single object, by keys
      def read_one(repository, query)
        raise NotImplementedError.new
      end

      def delete_one(repository, query)
        raise NotImplementedError.new
      end

      # Methods dealing with finding stuff by some query parameters
      def read_set(repository, query)
        raise NotImplementedError.new
      end

      def delete_set(repository, query)
        raise NotImplementedError.new
      end
      
      # # Shortcuts
      # Deprecated in favor of read_one
      # def first(repository, resource, query = {})
      #   raise ArgumentError.new("You cannot pass in a :limit option to #first") if query.key?(:limit)
      #   read_set(repository, resource, query.merge(:limit => 1)).first
      # end
      
      # Future Enumerable/convenience finders. Please leave in place. :-)
      # def each(repository, klass, query)
      #   raise NotImplementedError.new
      #   raise ArgumentError.new unless block_given?
      # end

    end # class AbstractAdapter
    
  end # module Adapters
end # module DataMapper
