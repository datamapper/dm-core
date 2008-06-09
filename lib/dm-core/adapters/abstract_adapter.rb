module DataMapper
  module Adapters

    class AbstractAdapter

      # Default TypeMap for all adapters.
      #
      # @return <DataMapper::TypeMap> default TypeMap
      def self.type_map
        @type_map ||= TypeMap.new
      end

      attr_reader :name, :uri
      attr_accessor :resource_naming_convention, :field_naming_convention

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

      #
      # Returns whether the storage_name exists.
      #
      # @param storage_name<String> a String defining the name of a storage,
      #   for example a table name.
      #
      # @return <Boolean> true if the storage exists
      #
      # TODO: move to dm-more/dm-migrations (if possible)
      def storage_exists?(storage_name)
        raise NotImplementedError
      end

      # TODO: remove this alias
      alias exists? storage_exists?

      #
      # Returns whether the field exists.
      #
      # @param storage_name<String> a String defining the name of a storage, for example a table name.
      # @param field_name<String> a String defining the name of a field, for example a column name.
      #
      # @return <Boolean> true if the field exists.
      #
      # TODO: move to dm-more/dm-migrations (if possible)
      def field_exists?(storage_name, field_name)
        raise NotImplementedError
      end

      # TODO: move to dm-more/dm-migrations
      def upgrade_model_storage(repository, model)
        raise NotImplementedError
      end

      # TODO: move to dm-more/dm-migrations
      def create_model_storage(repository, model)
        raise NotImplementedError
      end

      # TODO: move to dm-more/dm-migrations
      def destroy_model_storage(repository, model)
        raise NotImplementedError
      end

      # TODO: move to dm-more/dm-migrations
      def alter_model_storage(repository, *args)
        raise NotImplementedError
      end

      # TODO: move to dm-more/dm-migrations
      def create_property_storage(repository, property)
        raise NotImplementedError
      end

      # TODO: move to dm-more/dm-migrations
      def destroy_property_storage(repository, property)
        raise NotImplementedError
      end

      # TODO: move to dm-more/dm-migrations
      def alter_property_storage(repository, *args)
        raise NotImplementedError
      end

      # methods dealing with transactions

      #
      # Pushes the given Transaction onto the per thread Transaction stack so
      # that everything done by this Adapter is done within the context of said
      # Transaction.
      #
      # @param transaction<DataMapper::Transaction> a Transaction to be the
      #   'current' transaction until popped.
      #
      # TODO: move to dm-more/dm-transaction
      def push_transaction(transaction)
        @transactions[Thread.current] << transaction
      end

      #
      # Pop the 'current' Transaction from the per thread Transaction stack so
      # that everything done by this Adapter is no longer necessarily within the
      # context of said Transaction.
      #
      # @return <DataMapper::Transaction> the former 'current' transaction.
      #
      # TODO: move to dm-more/dm-transaction
      def pop_transaction
        @transactions[Thread.current].pop
      end

      #
      # Retrieve the current transaction for this Adapter.
      #
      # Everything done by this Adapter is done within the context of this
      # Transaction.
      #
      # @return <DataMapper::Transaction> the 'current' transaction for this Adapter.
      #
      # TODO: move to dm-more/dm-transaction
      def current_transaction
        @transactions[Thread.current].last
      end

      #
      # Returns whether we are within a Transaction.
      #
      # @return <Boolean> whether we are within a Transaction.
      #
      # TODO: move to dm-more/dm-transaction
      def within_transaction?
        !current_transaction.nil?
      end

      #
      # Produces a fresh transaction primitive for this Adapter
      #
      # Used by DataMapper::Transaction to perform its various tasks.
      #
      # @return <Object> a new Object that responds to :close, :begin, :commit,
      #   :rollback, :rollback_prepared and :prepare
      #
      # TODO: move to dm-more/dm-transaction (if possible)
      def transaction_primitive
        raise NotImplementedError
      end

      protected

      def normalize_uri(uri_or_options)
        uri_or_options
      end

      private

      # Instantiate an Adapter by passing it a DataMapper::Repository
      # connection string for configuration.
      def initialize(name, uri_or_options)
        raise ArgumentError, "+name+ should be a Symbol, but was #{name.class}", caller                                     unless name.kind_of?(Symbol)
        raise ArgumentError, "+uri_or_options+ should be a Hash, a Addressable::URI or a String but was #{uri_or_options.class}", caller unless [ Hash, Addressable::URI, String ].any? { |k| k === uri_or_options }

        @name = name
        @uri  = normalize_uri(uri_or_options)

        @resource_naming_convention = NamingConventions::UnderscoredAndPluralized
        @field_naming_convention    = NamingConventions::Underscored

        @transactions = Hash.new do |hash, key|
          hash.delete_if do |k, v|
            !k.respond_to?(:alive?) || !k.alive?
          end
          hash[key] = []
        end
      end
    end # class AbstractAdapter
  end # module Adapters
end # module DataMapper
