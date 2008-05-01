require 'forwardable'
module DataMapper
  class Collection < LazyArray
    attr_reader :repository

    def reload(options = {})
      query = Query.new(@repository, @model, keys.merge(:fields => @key_properties))
      query.update(options.merge(:reload => true))
      replace(@repository.adapter.read_set(@repository, query))
    end

    def load(values, reload = false)
      model = if @inheritance_property_index
        values.at(@inheritance_property_index) || @model
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
          resource = begin
            model.allocate
          rescue NoMethodError
            DataMapper.logger.error("Model not found for row: #{values.inspect} at index #{@inheritance_property_index}")
            raise $!
          end
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

    def clear
      each { |resource| remove_resource(resource) }
      super
    end

    def pop
      remove_resource(super)
    end

    def shift
      remove_resource(super)
    end

    def delete(resource, &block)
      remove_resource(super)
    end

    def delete_at(index)
      remove_resource(super)
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

      super()
      load_with(&loader)

      if inheritance_property = @model.inheritance_property(@repository.name)
        @inheritance_property_index = @properties_with_indexes[inheritance_property]
      end

      if (@key_properties = @model.key(@repository.name)).all? { |key| @properties_with_indexes.include?(key) }
        @key_property_indexes = @properties_with_indexes.values_at(*@key_properties)
      end
    end

    def wrap(entries)
      self.class.new(@repository, @model, @properties_with_indexes).replace(entries)
    end

    def remove_resource(resource)
      resource.collection = nil if resource && resource.collection == self
      resource
    end

    def keys
      entry_keys = @array.map { |resource| resource.key }

      keys = {}
      @key_properties.zip(entry_keys.transpose).each do |property,values|
        keys[property] = values
      end
      keys
    end
  end # class Collection
end # module DataMapper
