module DataMapper
  class Repository
    @adapters = {}

    def self.adapters
      @adapters
    end

    def self.context
      Thread.current[:dm_repository_contexts] ||= []
    end

    def self.default_name
      :default
    end

    attr_reader :name, :adapter

    def identity_map_get(model, key)
      @identity_maps[model][key]
    end

    def identity_map_set(resource)
      @identity_maps[resource.class][resource.key] = resource
    end

    # TODO: this should use current_scope too
    def get(model, key)
      @identity_maps[model][key] || @adapter.read(self, model, key)
    end

    def first(model, options)
      query = if current_scope = model.send(:current_scope)
        current_scope.merge(options.merge(:limit => 1))
      else
        Query.new(self, model, options.merge(:limit => 1))
      end
      @adapter.read_set(self, query).first
    end

    def all(model, options)
      query = if current_scope = model.send(:current_scope)
        current_scope.merge(options)
      else
        Query.new(self, model, options)
      end
      @adapter.read_set(self, query)
    end

    def save(resource)
      resource.child_associations.each { |a| a.save }

      success = if resource.new_record?
        if @adapter.create(self, resource)
          identity_map_set(resource)
          resource.instance_variable_set(:@new_record, false)
          resource.dirty_attributes.clear
          true
        else
          false
        end
      else
        if @adapter.update(self, resource)
          resource.dirty_attributes.clear
          true
        else
          false
        end
      end

      resource.parent_associations.each { |a| a.save }
      success
    end

    def destroy(resource)
      if @adapter.delete(self, resource)
        @identity_maps[resource.class].delete(resource.key)
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

    #
    # Produce a new Transaction for this Repository.
    #
    # ==== Returns
    # DataMapper::Adapters::Transaction:: A new Transaction (in state :none) that can be used to execute
    # code #with_transaction.
    #
    def transaction
      DataMapper::Transaction.new(self)
    end

    def to_s
      "#<DataMapper::Repository:#{@name}>"
    end

    private

    def initialize(name)
      raise ArgumentError, "+name+ should be a Symbol, but was #{name.class}", caller unless Symbol === name

      @name          = name
      @adapter       = self.class.adapters[name]
      @identity_maps = Hash.new { |h,model| h[model] = IdentityMap.new }
    end

  end # class Repository
end # module DataMapper
