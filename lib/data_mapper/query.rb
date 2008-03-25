module DataMapper
  class Query
    OPTIONS = [
      :reload, :offset, :limit, :order, :fields, :links, :includes, :conditions
    ]

    attr_reader :resource, *OPTIONS

    def update(other)
      other = self.class.new(resource, other) if other.kind_of?(Hash)

      @resource, @reload = other.resource, other.reload

      @offset = other.offset unless other.offset == 0
      @limit  = other.limit  unless other.limit.nil?

      @order    |= other.order
      @fields   |= other.fields
      @links    |= other.links
      @includes |= other.includes

      update_conditions!(other)

      self
    end

    def merge(other)
      self.dup.update(other)
    end

    def ==(other)
      return true if super
      @resource == other.resource &&
      @reload   == other.reload   &&
      @offset   == other.offset   &&
      @limit    == other.limit    &&
      @order    == other.order    &&
      @fields   == other.fields   &&
      @links    == other.links    &&
      @includes == other.includes &&
      @conditions.sort_by { |c| [ c[0].to_s, c[1].object_id, c[2] ] } == other.conditions.sort_by { |c| [ c[0].to_s, c[1].object_id, c[2] ] }
    end
    
    def parameters
      parameters = []
      conditions.each do |tuple|
        if value = tuple[2]
          parameters << value
        end
      end
      parameters
    end
    
    def resource_name
      @resource_name
    end

    private

    def initialize(resource, options = {})
      
      validate_resource!(resource)
      validate_options!(options)
      
      @repository = resource.repository
      @repository_name = @repository.name
      @resource_name = resource.resource_name(@repository_name)
      @properties = resource.properties(@repository_name)

      @resource   = resource                        # must be Class that includes DataMapper::Resource
      @reload     = options.fetch :reload,   false  # must be true or false
      @offset     = options.fetch :offset,   0      # must be an Integer greater than or equal to 0
      @limit      = options.fetch :limit,    nil    # must be an Integer greater than or equal to 1
      @order      = options.fetch :order,    []     # must be an Array of Symbol, Enumerable::Direction or Property
      @fields     = options.fetch :fields,   @properties.defaults # must be an Array of Symbol, String or Property
      @links      = options.fetch :links,    []     # must be an Array of Symbol, String, Property 1-jump-away or DM::Query::Path
      @includes   = options.fetch :includes, []     # must be an Array of Symbol, String, Property 1-jump-away or DM::Query::Path
      @conditions = []                              # must be an Array of triplets (or pairs when passing in raw String queries)

      # TODO: normalize order to DM::Query::Direction.new(DM::Property)
      # TODO: normalize fields to DM::Property
      # TODO: normalize links to DM::Query::Path
      # TODO: normalize includes to DM::Query::Path

      # TODO: loop over fields, and if the resource doesn't match
      # self.resource, append the property's resource to @links
      # eg:
      #if property.resource != self.resource
      #  @links << discover_path_for_property(property)
      #end

      # treat all non-options as conditions
      (options.keys - OPTIONS - OPTIONS.map(&:to_s)).each do |k|
        append_condition!(k, options[k])
      end

      # parse raw options[:conditions] differently
      if conditions_option = options[:conditions]
        @conditions << if conditions_option.size == 1
          [ conditions_option[0] ]
        else
          [ conditions_option[0], conditions_option[1..-1] ]
        end
      end
    end

    def initialize_copy(original)
      # deep-copy the condition tuples when copying the object
      @conditions = original.conditions.map { |tuple| tuple.dup }
    end

    def validate_resource!(resource)
      # validate the resource
      raise ArgumentError, "resource must be a Class, but is #{resource.class}" unless resource.kind_of?(Class)
      raise ArgumentError, 'resource must include DataMapper::Resource'         unless resource.included_modules.include?(DataMapper::Resource)
    end

    def validate_options!(options)
      raise ArgumentError, 'options must be a Hash' unless options.kind_of?(Hash)

      # validate the reload option
      if options.has_key?(:reload) && options[:reload] != true && options[:reload] != false
        raise ArgumentError, ":reload must be true or false, but was #{options[:reload].inspect}"
      end

      # validate the offset and limit options
      ([ :offset, :limit ] & options.keys).each do |attribute|
        value = options[attribute]
        raise ArgumentError, ":#{attribute} must be an Integer, but was #{value.class}" unless value.kind_of?(Integer)
      end
      raise ArgumentError, ':offset must be greater than or equal to 0' if options.has_key?(:offset) && !(options[:offset] >= 0)
      raise ArgumentError, ':limit must be greater than or equal to 1'  if options.has_key?(:limit)  && !(options[:limit]  >= 1)

      # validate the order, fields, links, includes and conditions options
      ([ :order, :fields, :links, :includes, :conditions ] & options.keys).each do |attribute|
        value = options[attribute]
        raise ArgumentError, ":#{attribute} must be an Array, but was #{value.class}" unless value.kind_of?(Array)
        raise ArgumentError, ":#{attribute} cannot be an empty Array"                 unless value.any?
      end
    end

    # TODO: spec this
    def validate_other!(other)
      raise ArgumentError, "other must be a #{self.class} or Hash object" unless other.kind_of?(self.class) || other.kind_of?(Hash)
    end

    def append_condition!(clause, value)
      operator = :eql

      property = case clause
        when Symbol::Operator
          operator = clause.type
          @properties[clause.value]
        when String
          @properties[clause]
        when Symbol
          @properties[clause]
        when DataMapper::Property
          clause
        else raise ArgumentError, "Condition type #{clause.inspect} not supported"
      end

      # XXX: should an exception be thrown if property is nil?

      @conditions << [ operator, property, value ]
    end

    # TODO: check for other mutually exclusive operator + clause
    # combinations.  For example if self's conditions were
    # [ :gt, :amount, 5 ] and the other's condition is [ :lt, :amount, 2 ]
    # there is a conflict.  When in conflict the other's conditions
    # overwrites self's conditions.

    # TODO: Another condition is when the other condition operator is
    # eql, this should over-write all the like,range and list operators
    # for the same clause, since we are now looking for an exact match.
    # Vice versa, passing in eql should overwrite all of those operators.

    def update_conditions!(other)

      # build an index of conditions by the clause and operator to
      # avoid nested looping
      conditions_index = Hash.new { |h,k| h[k] = {} }
      @conditions.each do |condition|
        next unless condition.size == 3  # only process triplets
        operator, clause = *condition
        conditions_index[clause][operator] = condition
      end

      # loop over each of the other's conditions, and overwrite the
      # conditions when in conflict
      other.conditions.each do |other_condition|
        if other_condition.size == 3 # only process triplets
          other_operator, other_clause, other_value = *other_condition

          if condition = conditions_index[other_clause][other_operator]
            operator, clause, value = *condition

            # overwrite the value in the existing condition
            condition[2] = case operator
              when :eql, :like : other_value
              when :gt,  :gte  : [ value, other_value ].min
              when :lt,  :lte  : [ value, other_value ].max
              when :not, :in   : Array(value) | Array(other_value)
            end

            next  # process the next other condition
          end
        end

        # otherwise append the other condition
        @conditions << other_condition.dup
      end
    end
  end # class Query
end # module DataMapper
