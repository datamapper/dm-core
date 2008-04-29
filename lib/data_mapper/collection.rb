require 'forwardable'

module DataMapper
  class Collection
    extend Forwardable
    include Enumerable

    def_instance_delegators :collection, :at, :empty?, :fetch, :index, :length, :rindex

    alias size length

    attr_reader :repository

    def reload(options = {})
      query = Query.new(@repository, @model, keys.merge(:fields => @key_properties))
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
          resource.collection = self
          return resource unless reload
        else
          resource = model.allocate
          self << resource
          resource.collection = self
          @key_properties.zip(key_values).each do |property,key_value|
            resource.instance_variable_set(property.instance_variable_name, key_value)
          end
          resource.instance_variable_set(:@new_record, false)
          @repository.identity_map_set(resource)
        end
      else
        resource = model.allocate
        self << resource
        resource.collection = self
        resource.instance_variable_set(:@new_record, false)
        resource.readonly!
      end

      @properties_with_indexes.each_pair do |property, i|
        resource.instance_variable_set(property.instance_variable_name, values.at(i))
      end

      self
    end

    def push(*resources)
      collection.push(*resources)
      self
    end

    alias << push

    def pop
      if resource = collection.pop
        remove_resource(resource)
      end
    end

    def shift
      if resource = collection.shift
        remove_resource(resource)
      end
    end

    def unshift(*resources)
      collection.unshift(*resources)
      self
    end

    def clear
      collection.clear
      self
    end

    def delete(resource, &block)
      if resource = collection.delete(resource, &block)
        remove_resource(resource)
      end
    end

    def delete_at(index)
      if resource = collection.delete_at(index)
        remove_resource(resource)
      end
    end

    def values_at(*args)
      copy.push(*collection.values_at(*args))
    end

    def slice(*args)
      resources = collection.slice(*args)

      if args.size == 1 && args.first.kind_of?(Integer)
        resources
      else
        copy.push(*resources)
      end
    end

    alias [] slice

    def insert(*args)
      collection.insert(*args)
      self
    end

    alias []= insert

    def first(*args)
      resources = collection.first(*args)
      args.empty? ? resources : copy.push(*resources)
    end

    def last(*args)
      resources = collection.last(*args)
      args.empty? ? resources : copy.push(*resources)
    end

    def reverse
      copy.push(*collection).reverse!
    end

    def reverse!
      collection.reverse!
      self
    end

    def each(&block)
      collection.each(&block)
      self
    end

    def each_index(&block)
      collection.each_index(&block)
      self
    end

    def reverse_each(&block)
      collection.reverse_each(&block)
      self
    end

    def collect!(&block)
      collection.collect!(&block)
      self
    end

    alias map! collect!

    def reject(&block)
      copy.push(*super)
    end

    def reject!(&block)
      rejected = collection.reject!(&block)
      rejected.nil? ? nil : self
    end

    alias delete_if reject!

    def select(&block)
      copy.push(*super)
    end

    def sort(&block)
      copy.push(*super)
    end

    def sort!(&block)
      collection.sort!(&block)
      self
    end

    def concat(other)
      copy.push(*collection + other.entries)
    end

    alias + concat

    def difference(other)
      copy.push(*collection - other.entries)
    end

    alias - difference

    def union(other)
      copy.push(*collection | other.entries)
    end

    alias | union

    def intersection(other)
      copy.push(*collection & other.entries)
    end

    alias & intersection

    def eql?(other)
      return true if super
      return hash == other.hash
    end

    alias == eql?

    def hash
      @repository.hash              +
      @model.hash                   +
      @properties_with_indexes.hash +
      @loader.hash                  +
      collection.hash
    end

    private

    # +properties_with_indexes+ is a Hash of Property and values Array index pairs.
    #   { Property<:id> => 1, Property<:name> => 2, Property<:notes> => 3 }
    def initialize(repository, model, properties_with_indexes, &loader)
      raise ArgumentError, "+repository+ must be a DataMapper::Repository, but was #{repository.class}", caller unless Repository === repository
      raise ArgumentError, "+model+ is a #{model.class}, but is not a type of Resource", caller                 unless Resource > model

      @repository              = repository
      @model                   = model
      @properties_with_indexes = properties_with_indexes
      @loader                  = loader

      if inheritance_property = @model.inheritance_property(@repository.name)
        @inheritance_property_index = @properties_with_indexes[inheritance_property]
      end

      if (@key_properties = @model.key(@repository.name)).all? { |key| @properties_with_indexes.include?(key) }
        @key_property_indexes = @properties_with_indexes.values_at(*@key_properties)
      end
    end

    def collection
      unless defined?(@collection)
        @collection = []
        @loader[self] if @loader
      end
      @collection
    end

    def copy
      self.class.new(@repository, @model, @properties_with_indexes, &@loader)
    end

    def remove_resource(resource)
      resource.collection = nil if resource.collection == self
      resource
    end

    def keys
      entry_keys = collection.map { |resource| resource.key }

      keys = {}
      @key_properties.zip(entry_keys.transpose).each do |property,values|
        keys[property] = values
      end
      keys
    end
  end # class Collection
end # module DataMapper
