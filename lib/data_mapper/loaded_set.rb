require 'set'

module DataMapper

  class LoadedSet

    attr_reader :repository

    def initialize(repository, model, properties)
      @repository = repository
      @model      = model
      @properties = properties
      @entries    = []

      if inheritance_property = @model.inheritance_property(@repository.name)
        @inheritance_property_index = @properties[inheritance_property]
      end

      if (@key_properties = @model.key(@repository.name)).all? { |key| @properties.include?(key) }
        @key_property_indexes = @properties.values_at(*@key_properties)
      end
    end

    def keys
      entry_keys = @entries.map { |resource| resource.key }

      keys = {}
      @key_properties.zip(entry_keys.transpose).each do |property,values|
        keys[property] = values
      end
      keys
    end

    def reload!(options = {})
      query = Query.new(@model, keys.merge(:fields => @key_properties))
      query.update(options.merge(:reload => true))
      @repository.adapter.read_set(@repository, query)
    end

    def add(values, reload = false)
      model = if @inheritance_property_index
        values.at(@inheritance_property_index)
      else
        @model
      end

      resource = nil

      if @key_property_indexes
        key_values = values.values_at(*@key_property_indexes)

        if resource = @repository.identity_map_get(model, key_values)
          @entries << resource
          resource.loaded_set = self
          return resource unless reload
        else
          resource = model.allocate
          @entries << resource
          resource.loaded_set = self
          @key_properties.zip(key_values).each do |property,key_value|
            resource.instance_variable_set(property.instance_variable_name, key_value)
          end
          resource.instance_variable_set(:@new_record, false)
          @repository.identity_map_set(resource)
        end
      else
        resource = model.allocate
        @entries << resource
        resource.loaded_set = self
        resource.instance_variable_set(:@new_record, false)
        resource.readonly!
      end

      @properties.each_pair do |property, i|
        resource.instance_variable_set(property.instance_variable_name, values.at(i))
      end

      self
    end

    alias << add

    def first
      @entries.first
    end

    # FIXME: Array#uniq! is really expensive.  Is there any way we can
    # avoid doing this, or at least minimize how often this method is
    # called?
    def entries
      @entries.uniq!
      @entries.dup
    end
  end # class LoadedSet

  class LazyLoadedSet < LoadedSet

    def initialize(*args, &block)
      raise "LazyLoadedSets require a materialization block. Use a LoadedSet instead." unless block_given?
      super(*args)
      @loader = block
    end

    def each(&block)
      entries.each { |entry| yield entry }
    end

    def entries
      @loader[self]

      class << self
        def entries
          super
        end
      end

      super
    end

  end # class LazyLoadedSet
end # module DataMapper
