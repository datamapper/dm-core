require 'set'

module DataMapper

  class LoadedSet

    attr_reader :repository

    # +properties+ is a Hash of Property and values Array index pairs.
    #   { Property<:id> => 1, Property<:name> => 2, Property<:notes> => 3 }
    def initialize(repository, type, properties)
      @repository = repository
      @type       = type
      @properties = properties
      @entries    = []

      @inheritance_property_index = if inheritance_property = @type.inheritance_property(@repository.name) && @properties.include?(inheritance_property)
        @properties[inheritance_property]
      end

      @key_property_indexes = if (@key_properties = @type.key(@repository.name)).all? { |key| @properties.key?(key) }
        @properties.values_at(*@key_properties)
      end
    end

    def keys
      # TODO: This is a really dirty way to implement this. My brain's just fried :p
      keys = {}
      entry_keys = @entries.map { |resource| resource.key }

      @key_properties.each_with_index do |property,i|
        keys[property] = entry_keys.map { |key| key[i] }
      end

      keys
    end

    def reload!(options = {})
      query = Query.new(@type, keys.merge(:fields => @key_properties))
      query.update(options.merge(:reload => true))
      @repository.adapter.read_set(@repository, query)
    end

    def materialize!(values, reload = false)
      type = if @inheritance_property_index
        values[@inheritance_property_index]
      else
        @type
      end

      resource = nil

      if @key_property_indexes
        key_values = @key_property_indexes.map { |i| values[i] }

        if resource = @repository.identity_map_get(type, key_values)
          @entries << resource
          resource.loaded_set = self
          return resource unless reload
        else
          resource = type.allocate
          @entries << resource
          @key_properties.each_with_index do |p,i|
            resource.instance_variable_set(p.instance_variable_name, key_values[i])
          end
          resource.loaded_set = self
          resource.instance_variable_set("@new_record", false)
          @repository.identity_map_set(resource)
        end
      else
        resource = type.allocate
        @entries << resource
        resource.readonly!
        resource.instance_variable_set("@new_record", false)
        resource.loaded_set = self
      end

      @properties.each_pair do |property, i|
        resource.instance_variable_set(property.instance_variable_name, values[i])
      end

      resource
    end

    def first
      @entries.first
    end

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
