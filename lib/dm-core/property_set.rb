module DataMapper
  # Set of Property objects, used to associate
  # queries with set of fields it performed over,
  # to represent composite keys (esp. for associations)
  # and so on.
  class PropertySet < SubjectSet
    include Enumerable

    def <<(property)
      clear_cache
      super
    end

    # Make sure that entry is part of this PropertySet
    #
    # @param [#to_s] name
    # @param [#name] entry
    #
    # @return [#name]
    #   the entry that is now part of this PropertySet
    #
    # @api semipublic
    def []=(name, entry)
      warn "#{self.class}#[]= is deprecated. Use #{self.class}#<< instead: #{caller.first}"
      raise "#{entry.class} is not added with the correct name" unless name && name.to_s == entry.name.to_s
      self << entry
      entry
    end

    def |(other)
      self.class.new(to_a | other.to_a)
    end

    def &(other)
      self.class.new(to_a & other.to_a)
    end

    def -(other)
      self.class.new(to_a - other.to_a)
    end

    def +(other)
      self.class.new(to_a + other.to_a)
    end

    def ==(other)
      to_a == other.to_a
    end

    # TODO: make PropertySet#reject return a PropertySet instance
    # @api semipublic
    def defaults
      @defaults ||= self.class.new(key | [ discriminator ].compact | reject { |property| property.lazy? }).freeze
    end

    # @api semipublic
    def key
      @key ||= self.class.new(select { |property| property.key? }).freeze
    end

    # @api semipublic
    def discriminator
      @discriminator ||= detect { |property| property.kind_of?(Property::Discriminator) }
    end

    # @api semipublic
    def indexes
      index_hash = {}
      each { |property| parse_index(property.index, property.field, index_hash) }
      index_hash
    end

    # @api semipublic
    def unique_indexes
      index_hash = {}
      each { |property| parse_index(property.unique_index, property.field, index_hash) }
      index_hash
    end

    # @api semipublic
    def get(resource)
      return [] if resource.nil?
      map { |property| resource.__send__(property.name) }
    end

    # @api semipublic
    def get!(resource)
      map { |property| property.get!(resource) }
    end

    # @api semipublic
    def set(resource, values)
      zip(values) { |property, value| resource.__send__("#{property.name}=", value) }
    end

    # @api semipublic
    def set!(resource, values)
      zip(values) { |property, value| property.set!(resource, value) }
    end

    # @api semipublic
    def loaded?(resource)
      all? { |property| property.loaded?(resource) }
    end

    # @api semipublic
    def valid?(values)
      zip(values.nil? ? [] : values).all? { |property, value| property.valid?(value) }
    end

    # @api semipublic
    def typecast(values)
      zip(values.nil? ? [] : values).map { |property, value| property.typecast(value) }
    end

    # @api private
    def property_contexts(property)
      contexts = []
      lazy_contexts.each do |context, properties|
        contexts << context if properties.include?(property)
      end
      contexts
    end

    # @api private
    def lazy_context(context)
      lazy_contexts[context] ||= []
    end

    # @api private
    def in_context(properties)
      properties_in_context = properties.map do |property|
        if (contexts = property_contexts(property)).any?
          lazy_contexts.values_at(*contexts)
        else
          property
        end
      end

      properties_in_context.flatten.uniq
    end

    # @api private
    def field_map
      Hash[ map { |property| [ property.field, property ] } ]
    end

    def inspect
      to_a.inspect
    end

    private

    # @api private
    def clear_cache
      @defaults, @key, @discriminator = nil
    end

    # @api private
    def lazy_contexts
      @lazy_contexts ||= {}
    end

    # @api private
    def parse_index(index, property, index_hash)
      case index
        when true
          index_hash[property] = [ property ]
        when Symbol
          index_hash[index] ||= []
          index_hash[index] << property
        when Array
          index.each { |idx| parse_index(idx, property, index_hash) }
      end
    end
  end # class PropertySet
end # module DataMapper
