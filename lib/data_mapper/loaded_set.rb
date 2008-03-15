module DataMapper
 
  class LoadedSet
 
    # +properties+ is a Hash of Property and values Array index pairs.
    #   { Property<:id> => 1, Property<:name> => 2, Property<:notes> => 3 }
    def initialize(repository, type, properties)
      @repository = repository
      @type = type
      @properties = properties
 
      @inheritance_property_index = if @inheritance_property = @type.inheritance_property(@repository.name) &&
        @properties.key?(@inheritance_property)
        @properties.values_at(@inheritance_property)
      else
        nil
      end
 
      @key_property_indexes = if (@key_properties = @type.keys(@repository.name)).all? { |key| @properties.key?(key) }
        @properties.values_at(@key_properties)
      else
        nil
      end
 
      @entries = []
    end
 
    def materialize!(values, reload = false)
      type = if @inheritance_property_index
        values[@inheritance_property_index]
      else
        @type
      end
 
      instance = nil
 
      if @key_property_indexes
        key_values = @key_property_indexes.map { |i| values[i] }
        instance = @repository.identity_map_get(type, key_values)
        @entries << instance
        instance.loaded_set = self
 
        if instance.nil?
          instance = type.allocate
          @key_properties.zip(key_values).each do |p,v|
            instance.instance_variable_set(p.instance_variable_name, v)
          end
          @repository.identity_map_set(instance)
        else
          return instance unless reload
        end
      else
        instance = type.allocate
        instance.readonly = true
        instance.instance_variable_set("@new_record", false)
        @entries << instance
        instance.loaded_set = self
      end
 
      @properties.each do |property, i|
        instance.instance_variable_set(property.instance_variable_name, values[i])
        instance.loaded_attributes << property.name
      end
 
      instance
    end
 
    def to_a
      @entries.dup
    end
  end
 
end