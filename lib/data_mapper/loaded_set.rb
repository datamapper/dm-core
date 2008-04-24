require 'forwardable'

module DataMapper
  class LoadedSet
    extend Forwardable
    include Enumerable

    def_instance_delegators :entries, :[], :size, :length, :first, :last

    attr_reader :repository

    def reload(options = {})
      query = Query.new(@model, keys.merge(:fields => @key_properties))
      query.update(options.merge(:reload => true))
      @repository.adapter.read_set(@repository, query)
    end

    def load(values, reload = false)
      model = if @inheritance_property_index
        values.at(@inheritance_property_index)
      else
        @model
      end

      resource = nil

      if @key_property_indexes
        key_values = values.values_at(*@key_property_indexes)

        if resource = @repository.identity_map_get(model, key_values)
          self << resource
          return resource unless reload
        else
          resource = model.allocate
          self << resource
          @key_properties.zip(key_values).each do |property,key_value|
            resource.instance_variable_set(property.instance_variable_name, key_value)
          end
          resource.instance_variable_set(:@new_record, false)
          @repository.identity_map_set(resource)
        end
      else
        resource = model.allocate
        self << resource
        resource.instance_variable_set(:@new_record, false)
        resource.readonly!
      end

      @properties_with_indexes.each_pair do |property, i|
        resource.instance_variable_set(property.instance_variable_name, values.at(i))
      end

      self
    end

    def add(resource)
      raise ArgumentError, "+resource+ should be a DataMapper::Resource, but was #{resource.class}" unless Resource === resource
      @resources << resource
      resource.loaded_set = self
    end

    alias << add

    def merge(*resources)
      resources.each { |resource| add(resource) }
      self
    end

    def delete(resource)
      raise ArgumentError, "+resource+ should be a DataMapper::Resource, but was #{resource.class}" unless Resource === resource
      @resources.delete(resource)
    end

    def entries
      @resources.dup
    end

    def each(&block)
      entries.each { |entry| yield entry }
      self
    end

    private

    # +properties_with_indexes+ is a Hash of Property and values Array index pairs.
    #   { Property<:id> => 1, Property<:name> => 2, Property<:notes> => 3 }
    def initialize(repository, model, properties_with_indexes)
      raise ArgumentError, "+repository+ must be a DataMapper::Repository, but was #{repository.class}", caller unless Repository === repository
      raise ArgumentError, "+model+ is a #{model.class}, but is not a type of Resource", caller                 unless Resource > model

      @repository              = repository
      @model                   = model
      @properties_with_indexes = properties_with_indexes
      @resources               = []

      if inheritance_property = @model.inheritance_property(@repository.name)
        @inheritance_property_index = @properties_with_indexes[inheritance_property]
      end

      if (@key_properties = @model.key(@repository.name)).all? { |key| @properties_with_indexes.include?(key) }
        @key_property_indexes = @properties_with_indexes.values_at(*@key_properties)
      end
    end

    def keys
      entry_keys = @resources.map { |resource| resource.key }

      keys = {}
      @key_properties.zip(entry_keys.transpose).each do |property,values|
        keys[property] = values
      end
      keys
    end
  end # class LoadedSet

  class LazyLoadedSet < LoadedSet
    def entries
      @loader[self]

      class << self
        def entries
          super
        end
      end

      super
    end

    private

    def initialize(*args, &block)
      raise "LazyLoadedSets require a materialization block. Use a LoadedSet instead." unless block_given?
      super
      @loader = block
    end
  end # class LazyLoadedSet
end # module DataMapper
