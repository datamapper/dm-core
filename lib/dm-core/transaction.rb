# TODO: move to dm-more/dm-transaction

module DataMapper
  class Transaction
    extend Chainable

    # @api private
    attr_accessor :state

    # @api private
    def none?
      state == :none
    end

    # @api private
    def begin?
      state == :begin
    end

    # @api private
    def rollback?
      state == :rollback
    end

    # @api private
    def commit?
      state == :commit
    end

    # Create a new Transaction
    #
    # @see Transaction#link
    #
    # In fact, it just calls #link with the given arguments at the end of the
    # constructor.
    #
    # @api public
    def initialize(*things)
      @transaction_primitives = {}
      self.state = :none
      @adapters = {}
      link(*things)
      if block_given?
        warn "Passing block to #{self.class.name}.new is deprecated (#{caller[0]})"
        commit { |*block_args| yield(*block_args) }
      end
    end

    # Associate this Transaction with some things.
    #
    # @param [Object] things
    #   the things you want this Transaction associated with:
    #
    #   Adapters::AbstractAdapter subclasses will be added as
    #     adapters as is.
    #   Arrays will have their elements added.
    #   Repository will have it's own @adapters added.
    #   Resource subclasses will have all the repositories of all
    #     their properties added.
    #   Resource instances will have all repositories of all their
    #     properties added.
    #
    # @param [Proc] block
    #   a block (taking one argument, the Transaction) to execute within
    #   this transaction. The transaction will begin and commit around
    #   the block, and rollback if an exception is raised.
    #
    # @api private
    def link(*things)
      unless none?
        raise "Illegal state for link: #{state}"
      end

      things.each do |thing|
        case thing
          when DataMapper::Adapters::AbstractAdapter
            @adapters[thing] = :none
          when DataMapper::Repository
            link(thing.adapter)
          when DataMapper::Model
            link(*thing.repositories)
          when DataMapper::Resource
            link(thing.model)
          when Array
            link(*thing)
          else
            raise "Unknown argument to #{self.class}#link: #{thing.inspect} (#{thing.class})"
        end
      end

      if block_given?
        commit { |*block_args| yield(*block_args) }
      else
        self
      end
    end

    # Begin the transaction
    #
    # Before #begin is called, the transaction is not valid and can not be used.
    #
    # @api private
    def begin
      unless none?
        raise "Illegal state for begin: #{state}"
      end

      each_adapter(:connect_adapter, [:log_fatal_transaction_breakage])
      each_adapter(:begin_adapter, [:rollback_and_close_adapter_if_begin, :close_adapter_if_none])
      self.state = :begin
    end

    # Commit the transaction
    #
    #   If no block is given, it will simply commit any changes made since the
    #   Transaction did #begin.
    #
    # @param block<Block>   a block (taking the one argument, the Transaction) to
    #   execute within this transaction. The transaction will begin and commit
    #   around the block, and roll back if an exception is raised.
    #
    # @api private
    def commit
      if block_given?
        unless none?
          raise "Illegal state for commit with block: #{state}"
        end

        begin
          self.begin
          rval = within { |*block_args| yield(*block_args) }
        rescue Exception => exception
          if begin?
            rollback
          end
          raise exception
        ensure
          unless exception
            if begin?
              commit
            end
            return rval
          end
        end
      else
        unless begin?
          raise "Illegal state for commit without block: #{state}"
        end
        each_adapter(:commit_adapter, [:log_fatal_transaction_breakage])
        each_adapter(:close_adapter, [:log_fatal_transaction_breakage])
        self.state = :commit
      end
    end

    # Rollback the transaction
    #
    # Will undo all changes made during the transaction.
    #
    # @api private
    def rollback
      unless begin?
        raise "Illegal state for rollback: #{state}"
      end
      each_adapter(:rollback_adapter_if_begin, [:rollback_and_close_adapter_if_begin, :close_adapter_if_none])
      each_adapter(:close_adapter_if_open, [:log_fatal_transaction_breakage])
      self.state = :rollback
    end

    # Execute a block within this Transaction.
    #
    # No #begin, #commit or #rollback is performed in #within, but this
    # Transaction will pushed on the per thread stack of transactions for each
    # adapter it is associated with, and it will ensures that it will pop the
    # Transaction away again after the block is finished.
    #
    # @param block<Block> the block of code to execute.
    #
    # @api private
    def within
      unless block_given?
        raise 'No block provided'
      end

      unless begin?
        raise "Illegal state for within: #{state}"
      end

      adapters = @adapters

      adapters.each_key do |adapter|
        adapter.push_transaction(self)
      end

      begin
        yield self
      ensure
        adapters.each_key do |adapter|
          adapter.pop_transaction
        end
      end
    end

    # @api private
    def method_missing(method, *args, &block)
      first_arg = args.first

      return super unless args.size == 1 && first_arg.kind_of?(Adapters::AbstractAdapter)
      return super unless match = method.to_s.match(/\A(.*)_(if|unless)_(none|begin|rollback|commit)\z/)

      action, condition, expected_state = match.captures
      return super unless respond_to?(action, true)

      state   = state_for(first_arg).to_s
      execute = (condition == 'if') == (state == expected_state)

      send(action, first_arg) if execute
    end

    # @api private
    def primitive_for(adapter)
      unless @adapters.include?(adapter)
        raise "Unknown adapter #{adapter}"
      end

      unless @transaction_primitives.include?(adapter)
        raise "No primitive for #{adapter}"
      end

      @transaction_primitives[adapter]
    end

    private

    # @api private
    def validate_primitive(primitive)
      [:close, :begin, :rollback, :commit].each do |meth|
        unless primitive.respond_to?(meth)
          raise "Invalid primitive #{primitive}: doesnt respond_to?(#{meth.inspect})"
        end
      end

      primitive
    end

    # @api private
    def each_adapter(method, on_fail)
      adapters = @adapters
      begin
        adapters.each_key do |adapter|
          send(method, adapter)
        end
      rescue Exception => exception
        adapters.each_key do |adapter|
          on_fail.each do |fail_handler|
            begin
              send(fail_handler, adapter)
            rescue Exception => inner_exception
              DataMapper.logger.fatal("#{self}#each_adapter(#{method.inspect}, #{on_fail.inspect}) failed with #{exception.inspect}: #{exception.backtrace.join("\n")} - and when sending #{fail_handler} to #{adapter} we failed again with #{inner_exception.inspect}: #{inner_exception.backtrace.join("\n")}")
            end
          end
        end
        raise exception
      end
    end

    # @api private
    def state_for(adapter)
      unless @adapters.include?(adapter)
        raise "Unknown adapter #{adapter}"
      end

      @adapters[adapter]
    end

    # @api private
    def do_adapter(adapter, what, prerequisite)
      unless @transaction_primitives.include?(adapter)
        raise "No primitive for #{adapter}"
      end

      state = state_for(adapter)

      unless state == prerequisite
        raise "Illegal state for #{what}: #{state}"
      end

      DataMapper.logger.debug("#{adapter.name}: #{what}")
      @transaction_primitives[adapter].send(what)
      @adapters[adapter] = what
    end

    # @api private
    def log_fatal_transaction_breakage(adapter)
      DataMapper.logger.fatal("#{self} experienced a totally broken transaction execution. Presenting member #{adapter.inspect}.")
    end

    # @api private
    def connect_adapter(adapter)
      if @transaction_primitives.key?(adapter)
        raise "Already a primitive for adapter #{adapter}"
      end

      @transaction_primitives[adapter] = validate_primitive(adapter.transaction_primitive)
    end

    # @api private
    def close_adapter_if_open(adapter)
      if @transaction_primitives.include?(adapter)
        close_adapter(adapter)
      end
    end

    # @api private
    def close_adapter(adapter)
      unless @transaction_primitives.include?(adapter)
        raise 'No primitive for adapter'
      end

      @transaction_primitives[adapter].close
      @transaction_primitives.delete(adapter)
    end

    # @api private
    def begin_adapter(adapter)
      do_adapter(adapter, :begin, :none)
    end

    # @api private
    def commit_adapter(adapter)
      do_adapter(adapter, :commit, :begin)
    end

    # @api private
    def rollback_adapter(adapter)
      do_adapter(adapter, :rollback, :begin)
    end

    # @api private
    def rollback_and_close_adapter(adapter)
      rollback_adapter(adapter)
      close_adapter(adapter)
    end

    module Adapter
      extend Chainable

      # @api private
      def self.included(base)
        [ :Repository, :Model, :Resource ].each do |name|
          DataMapper.const_get(name).send(:include, Transaction.const_get(name))
        end
      end

      # Produces a fresh transaction primitive for this Adapter
      #
      # Used by Transaction to perform its various tasks.
      #
      # @return [Object]
      #   a new Object that responds to :close, :begin, :commit,
      #   and :rollback,
      #
      # @api private
      def transaction_primitive
        DataObjects::Transaction.create_for_uri(normalized_uri)
      end

      # Pushes the given Transaction onto the per thread Transaction stack so
      # that everything done by this Adapter is done within the context of said
      # Transaction.
      #
      # @param [Transaction] transaction
      #   a Transaction to be the 'current' transaction until popped.
      #
      # @return [Array(Transaction)]
      #   the stack of active transactions for the current thread
      #
      # @api private
      def push_transaction(transaction)
        transactions << transaction
      end

      # Pop the 'current' Transaction from the per thread Transaction stack so
      # that everything done by this Adapter is no longer necessarily within the
      # context of said Transaction.
      #
      # @return [Transaction]
      #   the former 'current' transaction.
      #
      # @api private
      def pop_transaction
        transactions.pop
      end

      # Retrieve the current transaction for this Adapter.
      #
      # Everything done by this Adapter is done within the context of this
      # Transaction.
      #
      # @return [Transaction]
      #   the 'current' transaction for this Adapter.
      #
      # @api private
      def current_transaction
        transactions.last
      end

      chainable do
        protected

        # @api semipublic
        def open_connection
          current_connection || super
        end

        # @api semipublic
        def close_connection(connection)
          unless current_connection == connection
            super
          end
        end
      end

      private

      # @api private
      def transactions
        Thread.current[:dm_transactions] ||= []
      end

      # Retrieve the current connection for this Adapter.
      #
      # @return [Transaction]
      #   the 'current' connection for this Adapter.
      #
      # @api private
      def current_connection
        if transaction = current_transaction
          transaction.primitive_for(self).connection
        end
      end
    end # module Adapter

    # alias the MySQL, PostgreSQL, Sqlite3 and Oracle adapters to use transactions
    MysqlAdapter = PostgresAdapter = Sqlite3Adapter = OracleAdapter = SqlserverAdapter = Adapter

    module Repository

      # Produce a new Transaction for this Repository
      #
      # @return [Adapters::Transaction]
      #   a new Transaction (in state :none) that can be used
      #   to execute code #with_transaction
      #
      # @api public
      def transaction
        Transaction.new(self)
      end
    end # module Repository

    module Model
      # @api private
      def self.included(mod)
        mod.descendants.each { |model| model.extend self }
      end

      # Produce a new Transaction for this Resource class
      #
      # @return <Adapters::Transaction
      #   a new Adapters::Transaction with all Repositories
      #   of the class of this Resource added.
      #
      # @api public
      def transaction
        transaction = Transaction.new(self)
        transaction.commit { |block_args| yield(*block_args) }
      end
    end # module Model

    module Resource

      # Produce a new Transaction for the class of this Resource
      #
      # @return [Adapters::Transaction]
      #   a new Adapters::Transaction for the Repository
      #   of the class of this Resource added.
      #
      # @api public
      def transaction
        model.transaction { |*block_args| yield(*block_args) }
      end
    end # module Resource
  end # class Transaction

  module Adapters
    extendable do

      # @api private
      def const_added(const_name)
        if Transaction.const_defined?(const_name)
          adapter = const_get(const_name)
          adapter.send(:include, Transaction.const_get(const_name))
        end

        super
      end
    end
  end # module Adapters
end # module DataMapper
