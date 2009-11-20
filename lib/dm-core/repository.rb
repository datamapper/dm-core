module DataMapper
  class Repository
    include Extlib::Assertions
    extend Equalizer

    equalize :name, :adapter

    # Get the list of adapters registered for all Repositories,
    # keyed by repository name.
    #
    #   TODO: create example
    #
    # @return [Hash(Symbol => Adapters::AbstractAdapter)]
    #   the adapters registered for all Repositories
    #
    # @api private
    def self.adapters
      @adapters ||= {}
    end

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

    # @api semipublic
    attr_reader :name

    # Get the adapter for this repository
    #
    # Lazy loads adapter setup from registered adapters
    #
    #   TODO: create example
    #
    # @return [Adapters::AbstractAdapter]
    #   the adapter for this repository
    #
    # @raise [RepositoryNotSetupError]
    #   if there is no adapter registered for a repository named @name
    #
    # @api semipublic
    def adapter
      # Make adapter instantiation lazy so we can defer repository setup until it's actually
      # needed. Do not remove this code.
      @adapter ||=
        begin
          adapters = self.class.adapters

          unless adapters.key?(@name)
            raise RepositoryNotSetupError, "Adapter not set: #{@name}. Did you forget to setup?"
          end

          adapters[@name]
        end
    end

    # Get the identity for a particular model within this repository.
    #
    # If one doesn't yet exist, create a new default in-memory IdentityMap
    # for the requested model.
    #
    #   TODO: create example
    #
    # @param [Model] model
    #   Model whose identity map should be returned
    #
    # @return [IdentityMap]
    #   The IdentityMap for model in this Repository
    #
    # @api private
    def identity_map(model)
      @identity_maps[model.base_model] ||= IdentityMap.new
    end

    # Executes a block in the scope of this Repository
    #
    #   TODO: create example
    #
    # @yieldparam [Repository] repository
    #   yields self within the block
    #
    # @yield
    #   execute block in the scope of this Repository
    #
    # @api private
    def scope
      context = Repository.context

      context << self

      begin
        yield self
      ensure
        context.pop
      end
    end

    # Create one or more resource instances in this repository.
    #
    #   TODO: create example
    #
    # @param [Enumerable(Resource)] resources
    #   The list of resources (model instances) to create
    #
    # @return [Integer]
    #   The number of records that were actually saved into the data-store
    #
    # @api semipublic
    def create(resources)
      adapter.create(resources)
    end

    # Retrieve a collection of results of a query
    #
    #   TODO: create example
    #
    # @param [Query] query
    #   composition of the query to perform
    #
    # @return [Array]
    #   result set of the query
    #
    # @api semipublic
    def read(query)
      return [] unless query.valid?
      query.model.load(adapter.read(query), query)
    end

    # Update the attributes of one or more resource instances
    #
    #   TODO: create example
    #
    # @param [Hash(Property => Object)] attributes
    #   hash of attribute values to set, keyed by Property
    # @param [Collection] collection
    #   collection of records to be updated
    #
    # @return [Integer]
    #   the number of records updated
    #
    # @api semipublic
    def update(attributes, collection)
      return 0 unless collection.query.valid?
      adapter.update(attributes, collection)
    end

    # Delete one or more resource instances
    #
    #   TODO: create example
    #
    # @param [Collection] collection
    #   collection of records to be deleted
    #
    # @return [Integer]
    #   the number of records deleted
    #
    # @api semipublic
    def delete(collection)
      return 0 unless collection.query.valid?
      adapter.delete(collection)
    end

    # Return a human readable representation of the repository
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
