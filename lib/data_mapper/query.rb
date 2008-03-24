module DataMapper
  class Query
    # XXX: since :fields and :conditions are plural, shouldn't :link and :include
    # also be pluralized?  Not sure :order can be pluralized and still make sense tho
    OPTIONS = [
      :reload, :offset, :limit, :order, :fields, :link, :include, :conditions
    ]

    attr_reader :resource, *OPTIONS

    def initialize(resource, options = {})
      # validate the resource and options
      raise ArgumentError, "resource must be a Class, but is #{resource.class}" unless resource.kind_of?(Class)
      raise ArgumentError, 'resource must include DataMapper::Resource'         unless resource.included_modules.include?(DataMapper::Resource)
      raise ArgumentError, 'options must be a Hash'                             unless options.kind_of?(Hash)

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

      # validate the order, fields, link, include and conditions options
      ([ :order, :fields, :link, :include, :conditions ] & options.keys).each do |attribute|
        value = options[attribute]
        raise ArgumentError, ":#{attribute} must be an Array, but was #{value.class}" unless value.kind_of?(Array)
        raise ArgumentError, ":#{attribute} cannot be an empty Array"                 unless value.any?
      end

      @resource   = resource                       # must be Class that includes DataMapper::Resource
      @reload     = options.fetch :reload,  false  # must be true or false
      @offset     = options.fetch :offset,  0      # must be an Integer greater than or equal to 0
      @limit      = options.fetch :limit,   nil    # must be an Integer greater than or equal to 1
      @order      = options.fetch :order,   []     # TODO: must be an Array of ??
      @fields     = options.fetch :fields,  []     # TODO: must be an Array of ??
      @link       = options.fetch :link,    []     # TODO: must be an Array of ??
      @include    = options.fetch :include, []     # TODO: must be an Array of ??
      @conditions = []                             # must be an Array of triplets (or pairs when passing in raw String queries)

      (options.keys - OPTIONS).each do |k|
        append_condition!(k, options[k])
      end

      if conditions_option = options[:conditions]
        clause = conditions_option.shift
        append_condition!(clause, conditions_option.any? ? conditions_option.dup : nil)
      end
    end

    def update(other)
      # TODO: assert that other must be a DataMapper::Query object or a Hash

      # TODO: ask ssmoot if the other's resource doesn't make self.resource,
      # should we overwrite the resource or throw an exception?

      other = self.class.new(resource, other) if other.kind_of?(Hash)

      @resource, @reload = other.resource, other.reload

      @offset = other.offset unless other.offset == 0
      @limit  = other.limit  unless other.limit.nil?

      @order   |= other.order
      @fields  |= other.fields
      @link    |= other.link
      @include |= other.include

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
      @link     == other.link     &&
      @include  == other.include  &&
      @conditions.sort_by { |c| [ c[0].to_s, c[1].to_s, c[2] ]  } == other.conditions.sort_by { |c| [ c[0].to_s, c[1].to_s, c[2] ]  }
    end

    private

    def initialize_copy(original)
      # deep-copy the condition tuples when copying the object
      @conditions = original.conditions.map { |tuple| tuple.dup }
    end

    # XXX: if clause is a Symbol of Symbol::Operator, should we
    # validate that it is valid for the resource?

    def append_condition!(clause, value)
      @conditions.push case clause
        when Symbol::Operator : [ clause.type, clause.value, value ]
        when Symbol           : [ :eql,        clause,       value ]
        when String           : value.nil? ? [ clause ] : [ clause, Array(value) ]  # when passed in a raw Query
        else raise ArgumentError, "Condition type #{clause.inspect} not supported"
      end
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
            # if the other condition matches an existing condition, and
            # the operators match, then overwrite it
            operator, clause, value = *condition

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
