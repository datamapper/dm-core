module DataMapper
  module Adapters

    class Transaction
      attr_reader :state, :connection, :adapter
      def initialize(adapter)
        @adapter = adapter
        @state = :none
      end
      def begin
        raise "Illegal state for begin: #{@state}" unless @state == :none
        @connection = @adapter.create_connection
        @adapter.begin_transaction(self)
        @state = :begin
      end
      def commit
        raise "Illegal state for commit: #{@state}" unless @state == :begin
        @adapter.commit_transaction(self)
        @connection.close
        @state = :commit
      end
      def rollback
        raise "Illegal state for rollback: #{@state}" unless @state == :begin
        @adapter.rollback_transaction(self)
        @connection.close
        @state = :rollback
      end
    end

    class AbstractAdapter
      attr_reader :name, :uri
      attr_accessor :resource_naming_convention, :field_naming_convention
      attr_reader :transactions

      def current_transaction
        @transactions[Thread.current].last
      end

      def within_transaction?
        !current_transaction.nil?
      end

      def with_transaction(transaction, &block)
        @transactions[Thread.current] << transaction
        begin
          return(yield transaction)
        ensure
          @transactions[Thread.current].pop
        end
      end

      def in_transaction(&block)
        transaction = Transaction.new(self)
        begin
          transaction.begin
          rval = with_transaction(transaction, &block)
          transaction.commit if transaction.state == :begin
          return rval
        rescue Exception => e
          transaction.rollback if transaction.state == :begin
          raise e
        end
      end

      def begin_transaction(transaction)
        raise NotImplementedError
      end

      def commit_transaction(transaction)
        raise NotImplementedError
      end

      def rollback_transaction(transaction)
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
        raise ArgumentError, "+uri_or_options+ should be a Hash, a URI or a String but was #{uri_or_options.class}", caller unless [ Hash, URI, String ].any? { |k| k === uri_or_options }

        @name = name
        @uri  = normalize_uri(uri_or_options)

        @resource_naming_convention = NamingConventions::UnderscoredAndPluralized
        @field_naming_convention    = NamingConventions::Underscored

        @transactions = Hash.new do |hash, key| hash[key] = [] end
      end
    end # class AbstractAdapter
  end # module Adapters
end # module DataMapper
