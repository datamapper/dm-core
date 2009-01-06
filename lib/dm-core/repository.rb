module DataMapper
  class Repository
    include Extlib::Assertions

    ##
    # Get the list of adapters registered for all Repositories,
    # keyed by repository name.
    #
    # @return [Hash(Symbol => DataMapper::Adapters::AbstractAdapter)]
    #   the adapters registered for all Repositories
    def self.adapters
      @adapters ||= {}
    end

    ##
    # Get the stack of current repository contexts
    #
    # @return [Array]
    #   List of Repository contexts for the current Thread
    def self.context
      Thread.current[:dm_repository_contexts] ||= []
    end

    # Get the default name of this Repository
    # @return [Symbol] the default name of this repository
    # @api ???
    def self.default_name
      :default
    end

    attr_reader :name

    # Get the adapter for this repository
    #
    # Lazy loads adapter setup from registered adapters
    #
    # @return [DataMapper::Adapters::AbstractAdapter]
    #   the adapter for this repository
    #
    # @raise [ArgumentError]
    #   if there is no adapter registered for a repository named +@name+
    #
    # @api semipublic
    def adapter
      # Make adapter instantiation lazy so we can defer repository setup until it's actually
      # needed. Do not remove this code.
      @adapter ||= begin
        raise ArgumentError, "Adapter not set: #{@name}. Did you forget to setup?" \
          unless self.class.adapters.key?(@name)

        self.class.adapters[@name]
      end
    end

    ##
    # Get the identity for a particular model within this repository.
    #
    # If one doesn't yet exist, create a new default in-memory IdentityMap
    # for the requested model.
    #
    # @param [DataMapper::Model] model
    #   Model whose identity map should be returned
    #
    # @return [DataMapper::IdentityMap]
    #   The IdentityMap for +model+ in this Repository
    #
    # TODO: allow setting default secondary IdentityMap (eg., Memcache, I hope)
    def identity_map(model)
      @identity_maps[model] ||= IdentityMap.new
    end

    # TODO: spec this
    #
    # Executes a block in the scope of this Repository
    #
    # @yield [self] block to execute in the scope of this Repository
    # @yieldparam [DataMapper::Repository] +self+, the current Repository
    def scope
      Repository.context << self

      begin
        return yield(self)
      ensure
        Repository.context.pop
      end
    end

    ##
    # Create one or more resource instances in this repository.
    #
    # @param [Enumerable(DataMapper::Resource)] resources
    #   The list of resources (model instances) to create
    #
    # @return [Integer]
    #   The number of records that were actually saved into the data-store
    #
    # @api semipublic
    def create(resources)
      adapter.create(resources)
    end

    ##
    # retrieve a collection of results of a query
    #
    # @param [Query] query
    #   composition of the query to perform
    #
    # @return [DataMapper::Collection]
    #   Result set of the query
    # @return [NilClass]
    #   No object could be found which matches that query
    #
    # @see DataMapper::Query
    def read_many(query)
      adapter.read_many(query)
    end

    ##
    # retrieve a single resource instance by a query
    #
    # @param [DataMapper::Query] query
    #   composition of the query to perform
    #
    # @return [DataMapper::Resource]
    #   The first retrieved instance which matches the query
    # @return [NilClass]
    #   No object could be found which matches that query
    #
    # @see DataMapper::Query
    def read_one(query)
      adapter.read_one(query)
    end

    ##
    # Update the attributes of one or more resource instances
    #
    # @param [Hash(DataMapper::Property => Object)] attributes
    #   hash of attribute values to set, keyed by Property
    # @param [DataMapper::Query] query
    #   specifies which records are to be updated
    #
    # @return [Integer]
    #   the number of records updated
    #
    # @see DataMapper::Query
    def update(attributes, query)
      adapter.update(attributes, query)
    end

    ##
    # Delete one or more resource instances
    #
    # @param [DataMapper::Query] query
    #   specifies which records are to be deleted
    # @return [Integer]
    #   the number of records deleted
    # @see DataMapper::Query
    def delete(query)
      adapter.delete(query)
    end

    ##
    # Test whether this repository equals +other+. Repositories are equal if
    # they have the same name.
    #
    # @param [Object] other
    #   object to be compared to self
    #
    # @return [TrueClass, FalseClass]
    #   whether self equals +other+
    #
    # @api semipublic
    def eql?(other)
      return true if super
      name == other.name
    end

    alias == eql?

    # Get a concise, human readalbe representation of this repository
    # @return [String] concise human readable representation of this repository
    # @api private
    def to_s
      "#<DataMapper::Repository:#{@name}>"
    end

    private

    def initialize(name)
      assert_kind_of 'name', name, Symbol

      @name          = name
      @identity_maps = {}
    end

    # TODO: move to dm-more/dm-migrations
    module Migration
      # TODO: move to dm-more/dm-migrations
      def map(*args)
        type_map.map(*args)
      end

      # TODO: move to dm-more/dm-migrations
      def type_map
        @type_map ||= TypeMap.new(adapter.class.type_map)
      end

      ##
      # Determine whether a particular named storage exists in this repository
      #
      # @param [String] storage_name name of the storage to test for
      # @return [TrueClass, FalseClass] true if the data-store +storage_name+ exists
      #
      # TODO: move to dm-more/dm-migrations
      def storage_exists?(storage_name)
        adapter.storage_exists?(storage_name)
      end

      # TODO: move to dm-more/dm-migrations
      def migrate!
        Migrator.migrate(name)
      end

      # TODO: move to dm-more/dm-migrations
      def auto_migrate!
        AutoMigrator.auto_migrate(name)
      end

      # TODO: move to dm-more/dm-migrations
      def auto_upgrade!
        AutoMigrator.auto_upgrade(name)
      end
    end

    include Migration

    # TODO: move to dm-more/dm-transactions
    module Transaction
      ##
      # Produce a new Transaction for this Repository
      #
      # @return [DataMapper::Adapters::Transaction]
      #   a new Transaction (in state :none) that can be used
      #   to execute code #with_transaction
      #
      # TODO: move to dm-more/dm-transactions
      def transaction
        DataMapper::Transaction.new(self)
      end
    end

    include Transaction
  end # class Repository
end # module DataMapper
