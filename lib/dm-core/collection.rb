module DataMapper
  class Collection < LazyArray
    attr_reader :query

    def repository
      query.repository
    end

    def load(values)
      model = if @inheritance_property_index
        values.at(@inheritance_property_index) || query.model
      else
        query.model
      end

      # TODO: think about moving the logic here into Model#load
      resource = nil

      if @key_property_indexes
        key_values = values.values_at(*@key_property_indexes)

        if resource = repository.identity_map_get(model, key_values)
          add(resource)

          return resource unless query.reload?
        else
          resource = model.allocate
          resource.instance_variable_set(:@new_record, false)

          @key_properties.zip(key_values).each do |property,key_value|
            resource.instance_variable_set(property.instance_variable_name, key_value)
          end

          repository.identity_map_set(resource)

          add(resource)
        end
      else
        resource = model.allocate
        resource.instance_variable_set(:@new_record, false)
        resource.readonly!

        add(resource)
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

      # TODO: if loaded?, and the query is the same as self.query,
      # then return self

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

      query.repository.all(query.model, self.query.merge(query))
    end

    def first(*args)
      query = args.last.respond_to?(:merge) ? args.pop : {}

      # TODO: if loaded? and the passed-in query is a subset of
      #   self.query then delegate to super

      if args.any?
        all(query.merge(:limit => args.first))
      else
        all(query.merge(:limit => 1)).to_a.first
      end
    end

    def last(*args)
      reversed = reverse

      # TODO: if loaded? and the passed-in query is a subset of
      #   self.query then delegate to super

      # tell the collection to reverse the order of the
      # results coming out of the adapter
      reversed.add_reversed = !add_reversed?

      reversed.first(*args)
    end

    def at(offset)
      first(:offset => offset)
    end

    # TODO: add at()
    # TODO: add slice()
    # TODO: alias [] to slice()

    # TODO: add <<
    # TODO: add push()
    # TODO: add unshift()

    def reverse
      #if loaded?
      #  reversed = super
      #  reversed.query.reverse!
      #  return reversed
      #end

      all(self.query.reverse)
    end

    def replace(other)
      if loaded?
        each { |resource| orphan_resource(resource) }
      end
      other.each { |resource| relate_resource(resource) }
      super
    end

    def clear
      if loaded?
        each { |resource| orphan_resource(resource) }
      end
      super
    end

    def pop
      orphan_resource(super)
    end

    def shift
      orphan_resource(super)
    end

    def delete(resource, &block)
      orphan_resource(super)
    end

    def delete_at(index)
      orphan_resource(super)
    end

    def add_reversed=(boolean)
      query.add_reversed = boolean
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

    def add_reversed?
      query.add_reversed?
    end

    def wrap(entries)
      self.class.new(query).replace(entries)
    end

    def add(resource)
      relate_resource(resource)  # TODO: remove this once unshift/push relate resources
      add_reversed? ? unshift(resource) : push(resource)
    end

    def relate_resource(resource)
      resource.collection = self if resource
      resource
    end

    def orphan_resource(resource)
      resource.collection = nil if resource && resource.collection == self
      resource
    end

    def keys
      entry_keys = map { |resource| resource.key }

      keys = {}
      @key_properties.zip(entry_keys.transpose).each do |property,values|
        keys[property] = values.size == 1 ? values[0] : values
      end
      keys
    end

    def empty_collection
      # TODO: figure out how to create an empty collection
      #   - must have a null query object.. i.e. should not be possible
      #     to get any rows from it
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
