module DataMapper
  module Adapters

    class AbstractAdapter

      # Default TypeMap for all adapters.
      #
      # ==== Returns
      # DataMapper::TypeMap:: default TypeMap.
      def self.type_map
        @type_map ||= TypeMap.new
      end

      attr_reader :name, :uri
      attr_accessor :resource_naming_convention, :field_naming_convention

      def type_map
        self.class.type_map
      end

      # method for accessing the current adapter class' type_map from the
      # adapter instance.
      #
      # ==== Returns
      # DataMapper::TypeMap:: The type_map of the subclass
      def type_map
        self.class.type_map
      end

      # methods dealing with transactions

      #
      # Pushes the given Transaction onto the per thread Transaction stack so
      # that everything done by this Adapter is done within the context of said
      # Transaction.
      #
      # ==== Parameters
      # transaction<DataMapper::Transaction>:: A Transaction to be the
      #   'current' transaction until popped.
      #
      def push_transaction(transaction)
        @transactions[Thread.current] << transaction
      end

      #
      # Pop the 'current' Transaction from the per thread Transaction stack so
      # that everything done by this Adapter is no longer necessarily within the
      # context of said Transaction.
      #
      # ==== Returns
      # DataMapper::Transaction:: The former 'current' transaction.
      def pop_transaction
        @transactions[Thread.current].pop
      end

      #
      # Retrieve the current transaction for this Adapter.
      #
      # Everything done by this Adapter is done within the context of this
      # Transaction.
      #
      # ==== Returns
      # DataMapper::Transaction:: The 'current' transaction for this Adapter.
      def current_transaction
        @transactions[Thread.current].last
      end

      #
      # Returns whether we are within a Transaction.
      #
      # ==== Returns
      # Boolean:: Whether we are within a Transaction.
      #
      def within_transaction?
        !current_transaction.nil?
      end

      #
      # Produces a fresh transaction primitive for this Adapter
      #
      # Used by DataMapper::Transaction to perform its various tasks.
      #
      # ==== Returns
      # Object:: A new Object that responds to :close, :begin, :commit,
      #   :rollback, :rollback_prepared and :prepare
      #
      def transaction_primitive
        raise NotImplementedError
      end

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
      
      def upgrade_model_storage(repository, model)
        raise NotImplementedError
      end

      def create_model_storage(repository, model)
        raise NotImplementedError
      end

      def destroy_model_storage(repository, model)
        raise NotImplementedError
      end

      def alter_model_storage(repository, *args)
        raise NotImplementedError
      end

      def create_property_storage(repository, property)
        raise NotImplementedError
      end

      def destroy_property_storage(repository, property)
        raise NotImplementedError
      end

      def alter_property_storage(repository, *args)
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

      def batch_insertable?
        false
      end

      protected

      def normalize_uri(uri_or_options)
        uri_or_options
      end

      private

      # Instantiate an Adapter by passing it a DataMapper::Repository
      # connection string for configuration.
      def initialize(name, uri_or_options)
        raise ArgumentError, "+name+ should be a Symbol, but was #{name.class}", caller                                     unless Symbol === name
        raise ArgumentError, "+uri_or_options+ should be a Hash, a Addressable::URI or a String but was #{uri_or_options.class}", caller unless [ Hash, Addressable::URI, String ].any? { |k| k === uri_or_options }

        @name = name
        @uri  = normalize_uri(uri_or_options)

        @resource_naming_convention = NamingConventions::UnderscoredAndPluralized
        @field_naming_convention    = NamingConventions::Underscored

        @transactions = Hash.new do |hash, key| hash[key] = [] end
      end
    end # class AbstractAdapter
  end # module Adapters
end # module DataMapper
