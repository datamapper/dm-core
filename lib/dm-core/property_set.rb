module DataMapper
  # Set of Property objects, used to associate
  # queries with set of fields it performed over,
  # to represent composite keys (esp. for associations)
  # and so on.
  class PropertySet
    extend Deprecate
    include Enumerable

    deprecate :has_property?, :named?
    deprecate :slice,         :values_at
    deprecate :add,           :<<

    # @api semipublic
    def [](name)
      @properties[name]
    end

    # @api semipublic
    def []=(name, property)
      raise "Property is not added with the correct name" unless name == property.name
      add_property(property)
    end

    # @api semipublic
    def named?(name)
      @properties.key?(name.to_sym)
    end

    # @api semipublic
    def values_at(*names)
      @properties.values_at(*names)
    end

    # @api semipublic
    def <<(property)
      add_property(property)
    end

    # @api semipublic
    def include?(property)
      named?(property.name)
    end

    def each
      @order.each do |p|
        yield p
      end
    end

    def to_a
      @order
    end

    def to_ary
      to_a
    end

    def size
      @properties.size
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

    def ==(other)
      to_a == other.to_a
    end

    # @api semipublic
    def empty?
      @properties.empty?
    end

    # @api semipublic
    def index(property)
      each_index { |index| break index if at(index).name == property.name }
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
      @discriminator ||= detect { |property| property.kind_of?(Property::Discriminator) || property.type == Types::Discriminator }
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
      map { |property| [ property.field, property ] }.to_hash
    end

    def inspect
      to_a.inspect
    end

    private

    # @api semipublic
    def initialize(args = [])
      @order      = []
      @properties = args.map do |property|
        @order << property
        [ property.name, property ]
      end.to_mash
    end

    # @api private
    def initialize_copy(*)
      @order      = @order.dup
      @properties = @properties.dup
    end

    # @api private
    def add_property(property)
      clear_cache
      @order << property unless @order.include?(@property)
      @properties[property.name] = property
    end

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
