module DataMapper
  class Collection < LazyArray
    attr_reader :query

    def repository
      query.repository
    end

    def reload(options = {})
      @query = query.merge(keys.merge(:fields => @key_properties).merge(options))
      replace(repository.adapter.read_set(repository, query.merge(:reload => true)))
    end

    def load(values, reload = false)
      model = if @inheritance_property_index
        values.at(@inheritance_property_index) || query.model
      else
        query.model
      end

      resource = nil

      if @key_property_indexes
        key_values = values.values_at(*@key_property_indexes)

        if resource = repository.identity_map_get(model, key_values)
          resource.collection = self
          self << resource
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
          repository.identity_map_set(resource)
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

    def initialize(query, &loader)
      raise ArgumentError, "+query+ must be a DataMapper::Query, but was #{query.class}", caller unless query.kind_of?(Query)

      @query                   = query
      @properties_with_indexes = Hash[*query.fields.zip((0...query.fields.length).to_a).flatten]

      super()
      load_with(&loader)

      if inheritance_property = query.model.inheritance_property(repository.name)
        @inheritance_property_index = @properties_with_indexes[inheritance_property]
      end

      if (@key_properties = query.model.key(repository.name)).all? { |key| @properties_with_indexes.include?(key) }
        @key_property_indexes = @properties_with_indexes.values_at(*@key_properties)
      end
    end

    def wrap(entries)
      self.class.new(query).replace(entries)
    end

    def remove_resource(resource)
      resource.collection = nil if resource && resource.collection == self
      resource
    end

    def keys
      entry_keys = @array.map { |resource| resource.key }

      keys = {}
      @key_properties.zip(entry_keys.transpose).each do |property,values|
        keys[property] = values.size == 1 ? values[0] : values
      end
      keys
    end

    def method_missing(method_name, *args)
      if query.model.relationships(repository.name)[method_name]
        map { |e| e.send(method_name) }.flatten.compact
      else
        super
      end
    end
  end # class Collection
end # module DataMapper
