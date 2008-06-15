module DataMapper
  class Collection < LazyArray
    attr_reader :query

    def repository
      query.repository
    end

    def load(values)
      add(model.load(values, query))
    end

    def reload(query = {})
      @query = scoped_query(query)
      @query.update(:fields => @query.fields | @key_properties)
      replace(all(:reload => true))
    end

    def get(*key)
      if loaded?
        # loop over the collection to find the matching resource
        detect { |resource| resource.key == key }
      elsif query.limit || query.offset > 0
        # current query is exclusive, find resource within the set

        # TODO: use a subquery to retrieve the collection and then match
        #   it up against the key.  This will require some changes to
        #   how subqueries are generated, since the key may be a
        #   composite key.  In the case of DO adapters, it means subselects
        #   like the form "(a, b) IN(SELECT a,b FROM ...)", which will
        #   require making it so the Query condition key can be a
        #   Property or an Array of Property objects

        # use the brute force approach until subquery lookups work
        lazy_load
        get(*key)
      else
        # current query is all inclusive, lookup using normal approach
        first(model.to_query(repository, key))
      end
    end

    def get!(*key)
      get(*key) || raise(ObjectNotFoundError, "Could not find #{model.name} with key #{key.inspect} in collection")
    end

    def all(query = {})
      return self if query.kind_of?(Hash) ? query.empty? : query == self.query
      query = scoped_query(query)
      query.repository.read_many(query)
    end

    def first(*args)
      if loaded?
        if args.empty?
          return super
        elsif args.size == 1 && args.first.kind_of?(Integer)
          limit = args.shift
          return self.class.new(scoped_query(:limit => limit)) { |c| c.replace(super(limit)) }
        end
      end

      query = args.last.respond_to?(:merge) ? args.pop : {}
      query = scoped_query(query.merge(:limit => args.first || 1))

      if args.any?
        query.repository.read_many(query)
      else
        query.repository.read_one(query)
      end
    end

    def last(*args)
      return super if loaded? && args.empty?

      reversed = reverse

      # tell the collection to reverse the order of the
      # results coming out of the adapter
      reversed.query.add_reversed = !query.add_reversed?

      reversed.first(*args)
    end

    def at(offset)
      return super if loaded?
      offset >= 0 ? first(:offset => offset) : last(:offset => offset.abs - 1)
    end

    def slice(*args)
      return at(args.first) if args.size == 1 && args.first.kind_of?(Integer)

      if args.size == 2 && args.first.kind_of?(Integer) && args.last.kind_of?(Integer)
        offset, limit = args
      elsif args.size == 1 && args.first.kind_of?(Range)
        range  = args.first
        offset = range.first
        limit  = range.last - offset
        limit += 1 unless range.exclude_end?
      else
        raise ArgumentError, "arguments may be 1 or 2 Integers, or 1 Range object, was: #{args.inspect}"
      end

      all(:offset => offset, :limit => limit)
    end

    alias [] slice

    def reverse
      all(self.query.reverse)
    end

    def <<(resource)
      super
      relate_resource(resource)
      self
    end

    def push(*resources)
      super
      resources.each { |resource| relate_resource(resource) }
      self
    end

    def unshift(*resources)
      super
      resources.each { |resource| relate_resource(resource) }
      self
    end

    def replace(other)
      if loaded?
        each { |resource| orphan_resource(resource) }
      end
      super
      other.each { |resource| relate_resource(resource) }
      self
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

    def clear
      if loaded?
        each { |resource| orphan_resource(resource) }
      end
      super
      self
    end

    def create(attributes = {})
      repository.scope do
        resource = model.create(default_attributes.merge(attributes))
        self << resource unless resource.new_record?
        resource
      end
    end

    # TODO: delegate to Model.update
    def update(attributes = {})
      return true if attributes.empty?

      dirty_attributes = {}

      model.properties(repository.name).slice(*attributes.keys).each do |property|
        dirty_attributes[property] = attributes[property.name] if property
      end

      if loaded?
        return false unless repository.update(dirty_attributes, scoped_query) == size
      else
        return false unless repository.update(dirty_attributes, scoped_query) > 0
      end

      if loaded?
        each { |resource| resource.attributes = attributes }
      end

      true
    end

    # TODO: delegate to Model.destroy
    def destroy
      if loaded?
        return false unless repository.delete(scoped_query) == size

        identity_map = repository.identity_map(model)

        each do |resource|
          resource.instance_variable_set(:@new_record, true)
          identity_map.delete(resource.key)
          resource.dirty_attributes.clear

          model.properties(repository.name).each do |property|
            next unless resource.attribute_loaded?(property.name)
            resource.dirty_attributes[property] = property.get(resource)
          end
        end
      else
        return false unless repository.delete(scoped_query) > 0
      end

      clear

      true
    end

    def properties
      PropertySet.new(query.fields)
    end

    def relationships
      model.relationships(repository.name)
    end

    def default_attributes
      default_attributes = {}
      query.conditions.each do |tuple|
        operator, property, bind_value = *tuple

        next unless operator == :eql &&
          property.kind_of?(DataMapper::Property) &&
          ![ Array, Range ].any? { |k| bind_value.kind_of?(k) }
          !@key_properties.include?(property)

        default_attributes[property.name] = bind_value
      end
      default_attributes
    end

    protected

    def model
      query.model
    end

    private

    def initialize(query, &block)
      raise ArgumentError, "+query+ must be a DataMapper::Query, but was #{query.class}", caller unless query.kind_of?(Query)
      raise ArgumentError, 'a block must be supplied for lazy loading results', caller           unless block_given?

      @query          = query
      @key_properties = model.key(repository.name)

      super()

      load_with(&block)
    end

    def add(resource)
      query.add_reversed? ? unshift(resource) : push(resource)
      resource
    end

    def relate_resource(resource)
      return unless resource
      resource.collection = self
      resource
    end

    def orphan_resource(resource)
      return unless resource
      resource.collection = nil if resource.collection == self
      resource
    end

    def scoped_query(query = self.query)
      query.update(keys) if loaded?

      return self.query if query == self.query

      query = if query.kind_of?(Hash)
        Query.new(query.has_key?(:repository) ? query.delete(:repository) : self.repository, model, query)
      elsif query.kind_of?(Query)
        query
      else
        raise ArgumentError, "+query+ must be either a Hash or DataMapper::Query, but was a #{query.class}"
      end

      if query.limit || query.offset > 0
        set_relative_position(query)
      end

      self.query.merge(query)
    end

    def keys
      keys = {}

      if (entry_keys = map { |resource| resource.key }).any?
        @key_properties.zip(entry_keys.transpose) do |property,values|
          keys[property] = values.size == 1 ? values[0] : values
        end
      end

      keys
    end

    def set_relative_position(query)
      return if query == self.query

      if query.offset == 0
        return if !query.limit.nil? && !self.query.limit.nil? && query.limit <= self.query.limit
        return if  query.limit.nil? &&  self.query.limit.nil?
      end

      first_pos = self.query.offset + query.offset
      last_pos  = self.query.offset + self.query.limit if self.query.limit

      if limit = query.limit
        if last_pos.nil? || first_pos + limit < last_pos
          last_pos = first_pos + limit
        end
      end

      if last_pos && first_pos >= last_pos
        raise 'outside range'  # TODO: raise a proper exception object
      end

      query.update(:offset => first_pos)
      query.update(:limit => last_pos - first_pos) if last_pos
    end

    def method_missing(method_name, *args)
      if relationships[method_name]
        map { |e| e.send(method_name) }.flatten.compact
      else
        super
      end
    end
  end # class Collection
end # module DataMapper
