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

    attr_reader :name, :adapter, :type_map

    def identity_map_get(model, key)
      identity_map(model)[key]
    end

    def identity_map_set(resource)
      identity_map(resource.class)[resource.key] = resource
    end

    def identity_map(model)
      @identity_maps[model]
    end

    ##
    # retrieve a specific instance by key
    #
    # @param <Class> model the specific resource to retrieve from
    # @param <Key> key The keys to look for
    # @return <Class> the instance of the Resource retrieved
    # @return <NilClass> could not find the instance requested
    #
    #- TODO: this should use current_scope too
    def get(model, key)
      identity_maps[model][key] || adapter.read(self, model, key)
    end

    ##
    # retrieve a singular instance by query
    #
    # @param <Class> model the specific resource to retrieve from
    # @param <Hash, Query> options composition of the query to perform
    # @return <Class> the first retrieved instance which matches the query
    # @return <NilClass> no object could be found which matches that query
    # @see DataMapper::Query
    def first(model, options)
      query = if current_scope = model.send(:current_scope)
        current_scope.merge(options.merge(:limit => 1))
      else
        Query.new(self, model, options.merge(:limit => 1))
      end

      adapter.read_set(self, query).first
    end

    ##
    # retrieve a collection of results of a query
    #
    # @param <Class> model the specific resource to retrieve from
    # @param <Hash, Query> options composition of the query to perform
    # @return <Collection> result set of the query
    # @see DataMapper::Query
    def all(model, options)
      query = if current_scope = model.send(:current_scope)
        current_scope.merge(options)
      else
        Query.new(self, model, options)
      end
      adapter.read_set(self, query)
    end

    ##
    # save the instance into the data-store, updating if it already exists
    # If the instance has dirty items in it's associations, they also get saved
    #
    # @param <Class> resource the resource to return to the data-store
    # @return <True, False> results of the save
    def save(resource)
      resource.child_associations.each { |a| a.save }

      model = resource.class

      # set defaults for new resource
      if resource.new_record?
        model.properties(name).each do |property|
          next if resource.attribute_loaded?(property.name)
          property.set(resource, property.default_for(resource))
        end
      end

      success = false

      # save the resource if is dirty, or is a new record with a serial key
      if resource.dirty? || (resource.new_record? && model.key.any? { |p| p.serial? })
        if resource.new_record?
          if adapter.create(self, resource)
            identity_map_set(resource)
            resource.instance_variable_set(:@new_record, false)
            resource.dirty_attributes.clear
            properties_with_indexes = Hash[*model.properties.zip((0...model.properties.length).to_a).flatten]
            resource.collection = DataMapper::Collection.new(self, model, properties_with_indexes)
            resource.collection << resource
            success = true
          end
        else
          if adapter.update(self, resource)
            resource.dirty_attributes.clear
            success = true
          end
        end
      end

      resource.parent_associations.each { |a| a.save }

      success
    end

    ##
    # removes the resource from the data-store.  The instance will remain in active-memory, but will now be marked as a new_record and it's keys will be revoked
    #
    # @param <Class> resource the resource to be destroyed
    # @return <True, False> results of the destruction
    def destroy(resource)
      if adapter.delete(self, resource)
        identity_maps[resource.class].delete(resource.key)
        resource.instance_variable_set(:@new_record, true)
        resource.dirty_attributes.clear
        resource.class.properties(name).each do |property|
          resource.dirty_attributes << property if resource.attribute_loaded?(property.name)
        end
        true
      else
        false
      end
    end

    def migrate!
      Migrator.migrate(name)
    end

    def auto_migrate!
      AutoMigrator.auto_migrate(name)
    end

    def auto_upgrade!
      AutoMigrator.auto_upgrade(name)
    end

    ##
    # Produce a new Transaction for this Repository
    #
    #
    # @return <DataMapper::Adapters::Transaction> a new Transaction (in state
    #   :none) that can be used to execute code #with_transaction
    def transaction
      DataMapper::Transaction.new(self)
    end

    def to_s
      "#<DataMapper::Repository:#{@name}>"
    end

    def map(*args)
      type_map.map(*args)
    end

    def type_map
      @type_map ||= TypeMap.new(adapter.class.type_map)
    end

    ##
    #
    # @return <True, False> whether or not the data-store exists for this repo
    def storage_exists?(storage_name)
      adapter.storage_exists?(storage_name)
    end

    # TODO: remove this alias
    alias exists? storage_exists?

    private

    attr_reader :identity_maps

    def initialize(name)
      raise ArgumentError, "+name+ should be a Symbol, but was #{name.class}", caller unless Symbol === name
      raise ArgumentError, "Unknown adapter name: #{name}"                            unless self.class.adapters.has_key?(name)

      @name          = name
      @adapter       = self.class.adapters[name]
      @identity_maps = Hash.new { |h,model| h[model] = IdentityMap.new }
    end

  end # class Repository
end # module DataMapper
