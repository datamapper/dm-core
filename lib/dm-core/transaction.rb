# TODO: move to dm-more/dm-transaction

module DataMapper
  class Transaction
    attr_reader :transaction_primitives, :adapters, :state

    #
    # Create a new DataMapper::Transaction
    #
    # @see DataMapper::Transaction#link
    #
    # In fact, it just calls #link with the given arguments at the end of the
    # constructor.
    #
    # @api public
    def initialize(*things)
      @transaction_primitives = {}
      @state = :none
      @adapters = {}
      link(*things)
      commit { |*block_args| yield(*block_args) } if block_given?
    end

    #
    # Associate this Transaction with some things.
    #
    # @param things<any number of Object>  the things you want this Transaction
    #   associated with
    # @details [things a Transaction may be associatied with]
    #   DataMapper::Adapters::AbstractAdapter subclasses will be added as
    #     adapters as is.
    #   Arrays will have their elements added.
    #   DataMapper::Repositories will have their @adapters added.
    #   DataMapper::Resource subclasses will have all the repositories of all
    #     their properties added.
    #   DataMapper::Resource instances will have all repositories of all their
    #     properties added.
    # @param block<Block> a block (taking one argument, the Transaction) to execute
    #   within this transaction. The transaction will begin and commit around
    #   the block, and rollback if an exception is raised.
    #
    # @api private
    def link(*things)
      raise "Illegal state for link: #{@state}" unless @state == :none
      things.each do |thing|
        if thing.kind_of?(Array)
          link(*thing)
        elsif thing.kind_of?(DataMapper::Adapters::AbstractAdapter)
          @adapters[thing] = :none
        elsif thing.kind_of?(DataMapper::Repository)
          link(thing.adapter)
        elsif thing.kind_of?(Class) && thing.ancestors.include?(DataMapper::Resource)
          link(*thing.repositories)
        elsif thing.kind_of?(DataMapper::Resource)
          link(thing.model)
        else
          raise "Unknown argument to #{self}#link: #{thing.inspect}"
        end
      end
      return commit { |*block_args| yield(*block_args) } if block_given?
      return self
    end

    #
    # Begin the transaction
    #
    # Before #begin is called, the transaction is not valid and can not be used.
    #
    # @api private
    def begin
      raise "Illegal state for begin: #{@state}" unless @state == :none
      each_adapter(:connect_adapter, [:log_fatal_transaction_breakage])
      each_adapter(:begin_adapter, [:rollback_and_close_adapter_if_begin, :close_adapter_if_none])
      @state = :begin
    end

    #
    # Commit the transaction
    #
    # @param block<Block>   a block (taking the one argument, the Transaction) to
    #   execute within this transaction. The transaction will begin and commit
    #   around the block, and roll back if an exception is raised.
    #
    # @note
    #   If no block is given, it will simply commit any changes made since the
    #   Transaction did #begin.
    #
    # @api private
    def commit
      if block_given?
        raise "Illegal state for commit with block: #{@state}" unless @state == :none
        begin
          self.begin
          rval = within { |*block_args| yield(*block_args) }
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
    # @api private
    def rollback
      raise "Illegal state for rollback: #{@state}" unless @state == :begin
      each_adapter(:rollback_adapter_if_begin, [:rollback_and_close_adapter_if_begin, :close_adapter_if_none])
      each_adapter(:rollback_prepared_adapter_if_prepare, [:rollback_prepared_and_close_adapter_if_begin, :close_adapter_if_none])
      each_adapter(:close_adapter_if_open, [:log_fatal_transaction_breakage])
      @state = :rollback
    end

    #
    # Execute a block within this Transaction.
    #
    # @param block<Block> the block of code to execute.
    #
    # @note
    #   No #begin, #commit or #rollback is performed in #within, but this
    #   Transaction will pushed on the per thread stack of transactions for each
    #   adapter it is associated with, and it will ensures that it will pop the
    #   Transaction away again after the block is finished.
    #
    # @api private
    def within
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

    # @api private
    def method_missing(meth, *args, &block)
      if args.size == 1 && args.first.kind_of?(DataMapper::Adapters::AbstractAdapter)
        if (match = meth.to_s.match(/^(.*)_if_(none|begin|prepare|rollback|commit)$/))
          if self.respond_to?(match[1], true)
            self.send(match[1], args.first) if state_for(args.first).to_s == match[2]
          else
            super
          end
        elsif (match = meth.to_s.match(/^(.*)_unless_(none|begin|prepare|rollback|commit)$/))
          if self.respond_to?(match[1], true)
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

    # @api private
    def primitive_for(adapter)
      raise "Unknown adapter #{adapter}" unless @adapters.include?(adapter)
      raise "No primitive for #{adapter}" unless @transaction_primitives.include?(adapter)
      @transaction_primitives[adapter]
    end

    private

    # @api private
    def validate_primitive(primitive)
      [:close, :begin, :prepare, :rollback, :rollback_prepared, :commit].each do |meth|
        raise "Invalid primitive #{primitive}: doesnt respond_to?(#{meth.inspect})" unless primitive.respond_to?(meth)
      end
      return primitive
    end

    # @api private
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

    # @api private
    def state_for(adapter)
      raise "Unknown adapter #{adapter}" unless @adapters.include?(adapter)
      @adapters[adapter]
    end

    # @api private
    def do_adapter(adapter, what, prerequisite)
      raise "No primitive for #{adapter}" unless @transaction_primitives.include?(adapter)
      raise "Illegal state for #{what}: #{state_for(adapter)}" unless state_for(adapter) == prerequisite
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
      raise "Already a primitive for adapter #{adapter}" unless @transaction_primitives[adapter].nil?
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
      raise "No primitive for adapter" unless @transaction_primitives.include?(adapter)
      @transaction_primitives[adapter].close
      @transaction_primitives.delete(adapter)
    end

    # @api private
    def begin_adapter(adapter)
      do_adapter(adapter, :begin, :none)
    end

    # @api private
    def prepare_adapter(adapter)
      do_adapter(adapter, :prepare, :begin);
    end

    # @api private
    def commit_adapter(adapter)
      do_adapter(adapter, :commit, :prepare)
    end

    # @api private
    def rollback_adapter(adapter)
      do_adapter(adapter, :rollback, :begin)
    end

    # @api private
    def rollback_prepared_adapter(adapter)
      do_adapter(adapter, :rollback_prepared, :prepare)
    end

    # @api private
    def rollback_prepared_and_close_adapter(adapter)
      rollback_prepared_adapter(adapter)
      close_adapter(adapter)
    end

    # @api private
    def rollback_and_close_adapter(adapter)
      rollback_adapter(adapter)
      close_adapter(adapter)
    end

    module Adapter
      def self.included(base)
        [ :Repository, :Model, :Resource ].each do |name|
          DataMapper.const_get(name).send(:include, Transaction.const_get(name))
        end
      end

      ##
      # Produces a fresh transaction primitive for this Adapter
      #
      # Used by DataMapper::Transaction to perform its various tasks.
      #
      # @return [Object]
      #   a new Object that responds to :close, :begin, :commit,
      #   :rollback, :rollback_prepared and :prepare
      #
      # @api semipublic
      def transaction_primitive
        DataObjects::Transaction.create_for_uri(@uri)
      end

      ##
      # Pushes the given Transaction onto the per thread Transaction stack so
      # that everything done by this Adapter is done within the context of said
      # Transaction.
      #
      # @param [DataMapper::Transaction] transaction
      #   a Transaction to be the 'current' transaction until popped.
      #
      # @return [Array(DataMapper::Transaction)]
      #   the stack of active transactions for the current thread
      #
      # @api semipublic
      def push_transaction(transaction)
        transactions(Thread.current) << transaction
      end

      ##
      # Pop the 'current' Transaction from the per thread Transaction stack so
      # that everything done by this Adapter is no longer necessarily within the
      # context of said Transaction.
      #
      # @return [DataMapper::Transaction]
      #   the former 'current' transaction.
      #
      # @api semipublic
      def pop_transaction
        transactions(Thread.current).pop
      end

      ##
      # Retrieve the current transaction for this Adapter.
      #
      # Everything done by this Adapter is done within the context of this
      # Transaction.
      #
      # @return [DataMapper::Transaction]
      #   the 'current' transaction for this Adapter.
      #
      # @api semipublic
      def current_transaction
        transactions(Thread.current).last
      end

      ##
      # Returns whether we are within a Transaction.
      #
      # @return [TrueClass, FalseClass]
      #   whether we are within a Transaction.
      #
      # @api semipublic
      def within_transaction?
        !current_transaction.nil?
      end

      chainable do
        protected

        # @api semipublic
        def create_connection
          if within_transaction?
            current_transaction.primitive_for(self).connection
          else
            super
          end
        end

        # @api semipublic
        def close_connection(connection)
          unless within_transaction? && current_transaction.primitive_for(self).connection == connection
            super
          end
        end
      end

      private

      def transactions(thread)
        @transactions ||= {}
        unless @transactions[thread]
          @transactions.delete_if do |key, value|
            !key.respond_to?(:alive?) || !key.alive?
          end
          @transactions[thread] = []
        end
        @transactions[thread]
      end
    end # module Adapter

    # alias the MySQL and PostgreSQL adapters to use transactions
    MysqlAdapter = PostgresAdapter = Adapter

    module Repository
      ##
      # Produce a new Transaction for this Repository
      #
      # @return [DataMapper::Adapters::Transaction]
      #   a new Transaction (in state :none) that can be used
      #   to execute code #with_transaction
      #
      # @api semipublic
      def transaction
        DataMapper::Transaction.new(self)
      end
    end # module Repository

    module Model
      #
      # Produce a new Transaction for this Resource class
      #
      # @return <DataMapper::Adapters::Transaction
      #   a new DataMapper::Adapters::Transaction with all DataMapper::Repositories
      #   of the class of this DataMapper::Resource added.
      #
      # @api public
      def transaction
        DataMapper::Transaction.new(self) { |block_args| yield(*block_args) }
      end
    end # module Model

    module Resource
      # Produce a new Transaction for the class of this Resource
      #
      # @return [DataMapper::Adapters::Transaction]
      #   a new DataMapper::Adapters::Transaction with all DataMapper::Repositories
      #   of the class of this DataMapper::Resource added.
      #
      # @api public
      def transaction
        model.transaction { |*block_args| yield(*block_args) }
      end
    end # module Resource
  end # class Transaction

  module Adapters
    extendable do
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
