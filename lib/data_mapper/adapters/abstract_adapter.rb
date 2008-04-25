require 'socket'

module DataMapper
  module Adapters

    class Transaction
      HOST = "#{Socket::gethostbyname(Socket::gethostname)[0]}" rescue "localhost"
      @@counter = 0

      attr_reader :connections, :adapters, :id, :state

      #
      # Create a new DataMapper::Adapters::Transaction
      #
      # ==== Parameters
      # See DataMapper::Adapters::Transaction#link
      #
      # In fact, it just calls #link with the given arguments at the end of the constructor.
      #
      def initialize(*things, &block)
        @connections = {}
        @state = :none
        @id = "#{HOST}:#{$$}:#{@@counter += 1}"
        @adapters = {}
        link(*things)
        commit(&block) if block_given?
      end
      #
      # Associate this Transaction with some things.
      #
      # ==== Parameters
      # things<any number of Object>:: The things you want this Transaction associated with.
      #   DataMapper::Adapters::AbstractAdapter subclasses will be added as adapters as is.
      #   Arrays will have their elements added.
      #   DataMapper::Repositories will have their @adapters added.
      #   DataMapper::Resource subclasses will have all the repositories of all their properties added.
      #   DataMapper::Resource instances will have all repositories of all their properties added.
      # block<Block>:: A block (taking the one argument, the Transaction) to execute within this 
      #   transaction. The transaction will begin and commit around the block, and rollback if 
      #   an exception is raised.
      #
      def link(*things, &block)
        raise "Illegal state for link: #{@state}" unless @state == :none
        things.each do |thing|
          if thing.is_a?(Array)
            link(*thing)
          elsif thing.is_a?(DataMapper::Adapters::AbstractAdapter)
            @adapters[thing] = :none
          elsif thing.is_a?(DataMapper::Repository)
            link(thing.adapter)
          elsif thing.is_a?(Class) && thing.ancestors.include?(DataMapper::Resource)
            link(*thing.repositories)
          elsif thing.is_a?(DataMapper::Resource)
            link(thing.class)
          else
            raise "Unknown argument to #{self}#link: #{thing.inspect}"
          end
        end
        return commit(&block) if block_given?
        return self
      end
      #
      # Begin the transaction
      #
      # Before #begin is called, the transaction is not valid and can not be used.
      #
      def begin
        raise "Illegal state for begin: #{@state}" unless @state == :none
        each_adapter(:connect_adapter, [:log_fatal_transaction_breakage])
        each_adapter(:begin_adapter, [:rollback_and_close_adapter_if_begin, :close_adapter_if_none])
        @state = :begin
      end
      #
      # Commit the transaction
      #
      # ==== Parameters
      # block<Block>:: A block (taking the one argument, the Transaction) to execute within this 
      #   transaction. The transaction will begin and commit around the block, and rollback if 
      #   an exception is raised.
      #
      # If no block is given, it will simply commit any changes made since the Transaction did #begin.
      #
      def commit(&block)
        if block_given?
          raise "Illegal state for commit with block: #{@state}" unless @state == :none
          begin
            self.begin
            rval = within(&block)
            self.commit if @state == :begin
            return rval
          rescue Exception => e
            self.rollback if @state == :begin
            raise e
          end
        else
          raise "Illegal state for commit without block: #{@state}" unless @state == :begin
          each_adapter(:prepare_adapter, [:rollback_and_close_adapter_if_begin, :rollback_prepared_and_close_adapter_if_prepare])
          each_adapter(:commit_adapter, [:log_fatal_transaction_breakage])
          each_adapter(:close_adapter, [:log_fatal_transaction_breakage])
          @state = :commit
        end
      end
      #
      # Rollback the transaction
      #
      # Will undo all changes made during the transaction.
      #
      def rollback
        raise "Illegal state for rollback: #{@state}" unless @state == :begin
        each_adapter(:rollback_adapter, [:rollback_and_close_adapter_if_begin, :close_adapter_if_none])
        each_adapter(:close_adapter, [:log_fatal_transaction_breakage])
        @state = :rollback
      end
      #
      # Execute a block within this Transaction.
      #
      # ==== Parameters
      # block<Block>:: The block of code to execute.
      #
      # No #begin, #commit or #rollback is performed in #within, but this Transaction
      # will pushed on the per thread stack of transactions for each adapter it is associated with,
      # and it will ensures that it will pop the Transaction away again after the block is finished.
      #
      def within(&block)
        raise "No block provided" unless block_given?
        raise "Illegal state for within: #{@state}" unless @state == :begin
        @adapters.each do |adapter, state|
          adapter.push_transaction(self)
        end
        begin
          return yield(self)
        ensure
          @adapters.each do |adapter, state|
            adapter.pop_transaction
          end
        end
      end
      def method_missing(meth, *args, &block)
        if args.size == 1 && args.first.is_a?(DataMapper::Adapters::AbstractAdapter)
          if (match = meth.to_s.match(/^(.*)_if_(none|begin|prepare|rollback|commit)$/))
            if self.respond_to?(match[1])
              self.send(match[1], args.first) if state_for(args.first).to_s == match[2]
            else
              super
            end
          elsif (match = meth.to_s.match(/^(.*)_unless_(none|begin|prepare|rollback|commit)$/))
            if self.respond_to?(match[1])
              self.send(match[1], args.first) unless state_for(args.first).to_s == match[2]
            else
              super
            end
          else
            super
          end
        else
          super
        end
      end
      def connection_for(adapter)
        raise "No connection for #{adapter}, have you forgotten to call Transaction#begin?" unless @connections.include?(adapter)
        @connections[adapter]
      end

      private

      def each_adapter(method, on_fail)
        begin
          @adapters.each do |adapter, state|
            self.send(method, adapter)
          end
        rescue Exception => e
          @adapters.each do |adapter, state|
            on_fail.each do |fail_handler|
              begin
                self.send(fail_handler, adapter)
              rescue Exception => e2
                DataMapper.logger.fatal("#{self}#each_adapter(#{method.inspect}, #{on_fail.inspect}) failed with #{e.inspect}: #{e.backtrace.join("\n")} - and when sending #{fail_handler} to #{adapter} we failed again with #{e2.inspect}: #{e2.backtrace.join("\n")}")
              end
            end
          end
          raise e
        end
      end
      def state_for(adapter)
        raise "Unknown adapter #{adapter}" unless @adapters.include?(adapter)
        @adapters[adapter]
      end
      def do_adapter(adapter, what, prerequisite)
        raise "No connection for #{adapter}" unless @connections.include?(adapter)
        raise "Illegal state for #{what}: #{state_for(adapter)}" unless state_for(adapter) == prerequisite
        adapter.send("#{what}_transaction", self)
        @adapters[adapter] = what
      end
      def log_fatal_transaction_breakage(adapter)
        DataMapper.logger.fatal("#{self} experienced a totally broken transaction execution. Presenting member #{adapter.inspect}.")
      end
      def connect_adapter(adapter)
        raise "Already a connection for adapter #{adapter}" unless @connections[adapter].nil?
        @connections[adapter] = adapter.create_connection_outside_transaction
      end
      def close_adapter(adapter)
        raise "No connection for adapter" unless @connections.include?(adapter)
        @connections[adapter].close
        @connections.delete(adapter)
      end
      def begin_adapter(adapter)
        do_adapter(adapter, :begin, :none)
      end
      def prepare_adapter(adapter)
        do_adapter(adapter, :prepare, :begin);
      end
      def commit_adapter(adapter)
        do_adapter(adapter, :commit, :prepare)
      end
      def rollback_adapter(adapter)
        do_adapter(adapter, :rollback, :begin)
      end
      def rollback_prepared_adapter(adapter)
        do_adapter(adapter, :rollback_prepared, :prepare)
      end
      def rollback_prepared_and_close_adapter(adapter)
        rollback_prepared_adapter(adapter)
        close_adapter(adapter)
      end
      def rollback_and_close_adapter(adapter)
        rollback_adapter(adapter)
        close_adapter(adapter)
      end
    end

    class AbstractAdapter
      attr_reader :name, :uri
      attr_accessor :resource_naming_convention, :field_naming_convention
      attr_reader :transactions

      # methods dealing with transactions
      def push_transaction(transaction)
        @transactions[Thread.current] << transaction
      end

      def pop_transaction
        @transactions[Thread.current].pop
      end

      def current_transaction
        @transactions[Thread.current].last
      end

      def within_transaction?
        !current_transaction.nil?
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

      def rollback_prepared_transaction(transaction)
        raise NotImplementedError
      end

      def prepare_transaction(transaction)
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

      def create_connection
        raise NotImplementedError
      end

      def create_connection_outside_transaction
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
