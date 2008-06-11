module DataMapper
  class Repository
    @adapters = {}

    ##
    #
    # @return <Adapter> the adapters registered for this repository
    def self.adapters
      @adapters
    end

    def self.context
      Thread.current[:dm_repository_contexts] ||= []
    end

    def self.default_name
      :default
    end

    attr_reader :name

    def adapter
      @adapter ||= begin
        raise ArgumentError, "Adapter not set: #{@name}. Did you forget to setup?" \
          unless self.class.adapters.has_key?(@name)

        self.class.adapters[@name]
      end
    end

    def identity_map(model)
      @identity_maps[model]
    end

    ##
    # retrieve a resource instance by a query
    #
    # @param <Query> query composition of the query to perform
    # @return <DataMapper::Resource> the first retrieved instance which matches the query
    # @return <NilClass> no object could be found which matches that query
    # @see DataMapper::Query
    def read_one(query)
      adapter.read_one(query)
    end

    ##
    # retrieve a collection of results of a query
    #
    # @param <Query> query composition of the query to perform
    # @return <DataMapper::Collection> result set of the query
    # @see DataMapper::Query
    #
    # TODO: why pass in the model with the query?  Form the query inside the Model
    # and it'll carry along all the info necessary
    def read_many(query)
      adapter.read_many(query)
    end

    ##
    # save the instance into the data-store, updating if it already exists
    # If the instance has dirty items in it's associations, they also get saved
    #
    # @param <DataMapper::Resource> resource the resource to return to the data-store
    # @return <True, False> results of the save
    def save(resource)
      resource.child_associations.each { |a| a.save }

      model = resource.model

      # set defaults for new resource
      if resource.new_record?
        model.properties(name).each do |property|
          next if resource.attribute_loaded?(property.name)
          property.set(resource, property.default_for(resource))
        end
      end

      # save the resource if is dirty, or is a new record with a serial key
      success = if resource.dirty? || (resource.new_record? && model.key.any? { |p| p.serial? })
        if resource.new_record?
          if adapter.create([ resource ])
            resource.instance_variable_set(:@repository, self)
            resource.instance_variable_set(:@new_record, false)
            identity_map(resource.model).set(resource.key, resource)
          end
          true
        else
          adapter.update(resource.dirty_attributes, resource.to_query)
        end
      end

      if success
        resource.original_values.clear
      end

      resource.parent_associations.each { |a| a.save }

      success == true
    end

    ##
    # removes the resource from the data-store.  The instance will remain in active-memory, but will now be marked as a new_record and it's keys will be revoked
    #
    # @param <DataMapper::Resource> resource the resource to be destroyed
    # @return <True, False> results of the destruction
    def destroy(resource)
      if adapter.delete(resource.to_query)
        resource.instance_variable_set(:@new_record, true)
        resource.original_values.clear
        identity_map(resource.model).delete(resource.key)
        resource.model.properties(name).each do |property|
          # We'll set the original value to nil as if we had a new record
          resource.original_values[property.name] = nil if resource.attribute_loaded?(property.name)
        end
        true
      else
        false
      end
    end

    def eql?(other)
      return true if super
      name == other.name
    end

    alias == eql?

    def to_s
      "#<DataMapper::Repository:#{@name}>"
    end



    private

    def initialize(name)
      raise ArgumentError, "+name+ should be a Symbol, but was #{name.class}", caller unless name.kind_of?(Symbol)

      @name          = name
      @identity_maps = Hash.new { |h,model| h[model] = IdentityMap.new }
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
      #
      # @return <True, False> whether or not the data-store exists for this repo
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
      #
      # @return <DataMapper::Adapters::Transaction> a new Transaction (in state
      #   :none) that can be used to execute code #with_transaction
      #
      # TODO: move to dm-more/dm-transactions
      def transaction
        DataMapper::Transaction.new(self)
      end
    end

    include Transaction
  end # class Repository
end # module DataMapper
