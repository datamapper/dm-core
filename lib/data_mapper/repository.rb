require __DIR__ + 'support/errors'
require __DIR__ + 'identity_map'
require __DIR__ + 'scope'

module DataMapper
  class Repository
    @adapters = {}

    def self.adapters
      @adapters
    end

    def self.context
      Thread.current[:repository_contexts] ||= []
    end

    attr_reader :name, :adapter

    def identity_map_get(model, key)
      @identity_map.get(model, key)
    end

    def identity_map_set(resource)
      @identity_map.set(resource)
    end

    def get(model, key)
      @identity_map.get(model, key) || @adapter.read(self, model, key)
    end

    def first(model, options)
      query = if current_scope = model.send(:current_scope)
        current_scope.merge(options.merge(:limit => 1))
      else
        Query.new(model, options.merge(:limit => 1))
      end
      @adapter.read_set(self, query).first
    end

    def all(model, options)
      query = if current_scope = model.send(:current_scope)
        current_scope.merge(options)
      else
        Query.new(model, options)
      end
      @adapter.read_set(self, query).entries
    end

    def save(resource)
      resource.child_associations.each { |a| a.save }

      success = if resource.new_record?
        if @adapter.create(self, resource)
          @identity_map.set(resource)
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
        @identity_map.delete(resource.class, resource.key)
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

    private

    def initialize(name)
      raise ArgumentError, "+name+ should be a Symbol, but was #{name.class}", caller unless Symbol === name

      @name         = name
      @adapter      = self.class.adapters[name]
      @identity_map = IdentityMap.new
    end

  end # class Repository
end # module DataMapper
