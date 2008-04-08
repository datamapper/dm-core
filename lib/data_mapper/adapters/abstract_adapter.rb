require __DIR__.parent + 'loaded_set'
module DataMapper
  module Adapters

    class AbstractAdapter

      # Instantiate an Adapter by passing it a DataMapper::Repository
      # connection string for configuration.
      def initialize(name, uri, options = {})
        @name = name
        @uri = rewrite_uri(uri, options)

        @resource_naming_convention = NamingConventions::UnderscoredAndPluralized
        @field_naming_convention    = NamingConventions::Underscored
      end

      def batch_insertable?
        false
      end

      attr_reader :name
      attr_accessor :resource_naming_convention
      attr_accessor :field_naming_convention

      # Methods dealing with a single resource object
      def create(repository, resource)
        raise NotImplementedError
      end

      def read(repository, resource, key)
        raise NotImplementedError
      end

      def update(repository, resource)
        raise NotImplementedError
      end

      def delete(repository, resource)
        raise NotImplementedError
      end

      # Methods dealing with locating a single object, by keys
      def read_one(repository, query)
        raise NotImplementedError
      end

      # Methods dealing with finding stuff by some query parameters
      def read_set(repository, query)
        raise NotImplementedError
      end

      def delete_set(repository, query)
        raise NotImplementedError
      end

      # # Shortcuts
      # Deprecated in favor of read_one
      # def first(repository, resource, query = {})
      #   raise ArgumentError, "You cannot pass in a :limit option to #first" if query.key?(:limit)
      #   read_set(repository, resource, query.merge(:limit => 1)).first
      # end

      # Future Enumerable/convenience finders. Please leave in place. :-)
      # def each(repository, klass, query)
      #   raise NotImplementedError
      #   raise ArgumentError unless block_given?
      # end


      def rewrite_uri(uri, options)
        uri
      end

    end # class AbstractAdapter

  end # module Adapters
end # module DataMapper
