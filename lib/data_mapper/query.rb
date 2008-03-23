module DataMapper
  class Query
    OPTIONS = [
      :reload, :offset, :limit, :order, :fields, :link, :include, :conditions
    ]

    attr_reader :adapter, :model, *OPTIONS

    def initialize(adapter, model, options = {})
      # TODO: assert adapter and model are expected object types

      # TODO: abstact into assert_boolean_keys!(options, *keys) helper
      if options.has_key?(:reload) && reload != true && reload != false
        raise ArgumentError, ":relad must be true or false, but was #{conditions_option.inspect}"
      end

      # TODO: abstract into assert_integer_keys!(options, *keys) helper
      ([ :offset, :limit ] & options.keys).each do |attribute|
        option = options[attribute]
        raise ArgumentError, ":#{attribute} must be an Integer, but was #{option.inspect}" unless option.kind_of?(Integer)
      end

      # TODO: abstract into assert_array_keys!(options, *keys) helper
      ([ :order, :fields, :link, :include, :conditions ] & options.keys).each do |attribute|
        option = options[attribute]
        raise ArgumentError, ":#{attribute} must be an Array, but was #{option.inspect}" unless option.kind_of?(Array)
        raise ArgumentError, ":#{attribute} cannot be an empty Array" unless option.any?
      end

      @adapter, @model = adapter, model

      @reload     = options.fetch :reload,  false
      @offset     = options.fetch :offset,  0
      @limit      = options.fetch :limit,   nil
      @order      = options.fetch :order,   []
      @fields     = options.fetch :fields,  []
      @link       = options.fetch :link,    []
      @include    = options.fetch :include, []
      @conditions = []

      (options.keys - OPTIONS).each do |k|
        append_condition!(k, options[k])
      end

      if conditions_option = options[:conditions]
        clause = conditions_option.shift
        append_condition!(clause, conditions_option.any? ? conditions_option : nil)
      end
    end

    def update(other)
      other = self.class.new(adapter, model, other) unless other.kind_of?(self.class)

      @adapter, @model, @reload = other.adapter, other.model, other.reload

      @offset = other.offset if other.offset
      @limit  = other.limit  if other.limit

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

    private

    def initialize_copy(original)
       @conditions = original.conditions.map { |tuple| tuple.dup }
    end

    def append_condition!(clause, value)
      @conditions << case clause
        when Symbol::Operator : [ clause.type, clause.value, value ]
        when Symbol           : [ :eql,        clause,       value ]
        when String           : [ clause, value ]  # return a pair when passed in raw SQL
        else raise ArgumentError, "Condition type #{clause.inspect} not supported"
      end
    end

    # TODO: check for other mutually exclusive operator + clause
    # combinations.  For example if self's conditions were
    # [ :gt, :amount, 5 ] and the other's condition is [ :lt, :amount, 2 ]
    # there is a conflict.  When in conflict the other's conditions
    # overwrites self's conditions.

    def update_conditions!(other)

      # build an index of conditions by the clause and operator to
      # avoid nested looping
      conditions_index = Hash.new { |h,k| h[k] = {} }
      @conditions.each do |condition|
        next unless condition.size == 3
        operator, clause = *condition
        conditions_index[clause][operator] = condition
      end

      # loop over each of the other's conditions, and overwrite the
      # conditions when in conflict
      other.conditions.each do |other_condition|
        other_operator, other_clause, other_value = *other_condition

        if condition = conditions_index[other_clause][other_operator]
          operator, clause, value = *condition

          condition[2] = case operator
            when :eql, :like : other_value
            when :gt,  :gte  : [ value, other_value ].min
            when :lt,  :lte  : [ value, other_value ].max
            when :not, :in   : Array(value) | Array(other_value)
            else value
          end
        else
          @conditions << [ other_operator, other_clause, other_value ]
        end
      end
    end
  end # class Query
end # module DataMapper
