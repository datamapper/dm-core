module DataMapper
  class Collection < LazyArray
    attr_reader :query

    def repository
      query.repository
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
          resource = model.allocate
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

      resource
    end

    def reload(query = {})
      query[:fields] ||= self.query.fields
      query[:fields]  |= @key_properties

      @query = self.query.merge(keys.merge(query))

      replace(all(:reload => true))
    end

    def all(query = {})
      if Hash === query
        return self if query.empty?
        query = self.query.class.new(self.query.repository, self.query.model, query)
      end

      first_pos = self.query.offset + query.offset
      last_pos  = self.query.offset + self.query.limit if self.query.limit

      if limit = query.limit
        if last_pos.nil? || first_pos + limit < last_pos
          last_pos = first_pos + limit
        end
      end

      # return empty collection if outside range
      if last_pos && first_pos >= last_pos
        return empty_collection
      end

      query.update(:offset => first_pos)
      query.update(:limit => last_pos - first_pos) if last_pos

      query.model.all(self.query.merge(query))
    end

    def first(*args)
      query = args.last.respond_to?(:merge) ? args.pop : {}

      # TODO: if the collection is loaded, and no query was provided,
      # then try to access it like an Array
      #if Hash === query && query.empty? && loaded?
      #  return super
      #end

      if args.any?
        all(query.merge(:limit => args.first))
      else
        all(query.merge(:limit => 1)).to_a.first
      end
    end

    def last(*args)
      query = args.last.respond_to?(:merge) ? args.pop.dup : {}
      query = self.query.class.new(self.query.repository, self.query.model, query) if Hash === query

      # get the default sort order
      order = query.order
      order = self.query.order.any? ? self.query.order : query.model.key if order.empty?
      query.update(:order => order)

      # reverse the sort order
      query.update(:order => query.order.map { |o| o.reverse })

      if args.any?
        first(args.shift, query).reverse
      else
        first(query)
      end
    end

    # TODO: add at()
    # TODO: add slice()
    # TODO: alias [] to slice()

    def clear
      if loaded?
        each { |resource| remove_resource(resource) }
      end
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

    def empty_collection
      # TODO: figure out how to create an empty collection
      []
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
