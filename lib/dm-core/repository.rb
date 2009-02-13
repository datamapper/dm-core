module DataMapper
  class Repository
    include Extlib::Assertions

    ##
    # Get the list of adapters registered for all Repositories,
    # keyed by repository name.
    #
    #   TODO: create example
    #
    # @return [Hash(Symbol => DataMapper::Adapters::AbstractAdapter)]
    #   the adapters registered for all Repositories
    #
    # @api private
    def self.adapters
      @adapters ||= {}
    end

    ##
    # Get the stack of current repository contexts
    #
    #   TODO: create example
    #
    # @return [Array]
    #   List of Repository contexts for the current Thread
    #
    # @api private
    def self.context
      Thread.current[:dm_repository_contexts] ||= []
    end

    ##
    # Get the default name of this Repository
    #
    #   TODO: create example
    #
    # @return [Symbol]
    #   the default name of this repository
    #
    # @api private
    def self.default_name
      :default
    end

    attr_reader :name

    ##
    # Get the adapter for this repository
    #
    # Lazy loads adapter setup from registered adapters
    #
    #   TODO: create example
    #
    # @return [DataMapper::Adapters::AbstractAdapter]
    #   the adapter for this repository
    #
    # @raise [ArgumentError]
    #   if there is no adapter registered for a repository named @name
    #
    # @api semipublic
    def adapter
      # Make adapter instantiation lazy so we can defer repository setup until it's actually
      # needed. Do not remove this code.
      @adapter ||=
        begin
          raise RepositoryNotSetupError, "Adapter not set: #{@name}. Did you forget to setup?" \
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
    #   TODO: create example
    #
    # @param [DataMapper::Model] model
    #   Model whose identity map should be returned
    #
    # @return [DataMapper::IdentityMap]
    #   The IdentityMap for model in this Repository
    #
    # @api private
    def identity_map(model)
      @identity_maps[model.base_model] ||= IdentityMap.new
    end

    ##
    # Executes a block in the scope of this Repository
    #
    #   TODO: create example
    #
    # @yieldparam [DataMapper::Repository] repository
    #   yields self within the block
    #
    # @yield
    #   execute block in the scope of this Repository
    #
    # @api private
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
    #   TODO: create example
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
    # Retrieve a collection of results of a query
    #
    #   TODO: create example
    #
    # @param [Query] query
    #   composition of the query to perform
    #
    # @return [Array]
    #   Result set of the query
    #
    # @api semipublic
    def read_many(query)
      adapter.read_many(query)
    end

    ##
    # Retrieve a single resource instance by a query
    #
    #   TODO: create example
    #
    # @param [DataMapper::Query] query
    #   composition of the query to perform
    #
    # @return [DataMapper::Resource,NilClass]
    #   The first retrieved instance which matches the query, or nil
    #   if none found
    #
    # @api semipublic
    def read_one(query)
      adapter.read_one(query)
    end

    ##
    # Update the attributes of one or more resource instances
    #
    #   TODO: create example
    #
    # @param [Hash(DataMapper::Property => Object)] attributes
    #   hash of attribute values to set, keyed by Property
    # @param [DataMapper::Query] query
    #   specifies which records are to be updated
    #
    # @return [Integer]
    #   the number of records updated
    #
    # @api semipublic
    def update(attributes, query)
      adapter.update(attributes, query)
    end

    ##
    # Delete one or more resource instances
    #
    #   TODO: create example
    #
    # @param [DataMapper::Query] query
    #   specifies which records are to be deleted
    #
    # @return [Integer]
    #   the number of records deleted
    #
    # @api semipublic
    def delete(query)
      adapter.delete(query)
    end

    ##
    # Tests Equality of Repository objects
    #
    #   TODO: create example
    #
    # @param [Object] other
    #   object to be compared to self
    #
    # @return [TrueClass, FalseClass]
    #   whether self equals other
    #
    # @api semipublic
    def eql?(other)
      if equal?(other)
        return true
      end

      name.eql?(other.name)
    end

    alias == eql?

    ##
    # Return a human readalbe representation of the repository
    #
    #   TODO: create example
    #
    # @return [String]
    #   human readable representation of the repository
    #
    # @api private
    def inspect
      "#<#{self.class.name} @name=#{@name}>"
    end

    private

    ##
    # Initializes a new Repository
    #
    #   TODO: create example
    #
    # @param [Symbol] name
    #   The name of the Repository
    #
    # @api semipublic
    def initialize(name)
      assert_kind_of 'name', name, Symbol

      @name          = name
      @identity_maps = {}
    end
  end # class Repository
end # module DataMapper
