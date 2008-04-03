module DataMapper
  class Query
    class Direction
      attr_reader :property, :direction

      def ==(other)
        return true if super
        hash == other.hash
      end

      alias eql? ==

      def hash
        @property.hash + @direction.hash
      end

      private

      def initialize(property, direction = :asc)
        @property, @direction = property, direction
      end
    end

    class Operator
      attr_reader :value, :type, :options

      def initialize(value, type, options = nil)
        @value, @type, @options = value, type, options
      end

      def to_sym
        @value
      end
    end

    OPTIONS = [
      :reload, :offset, :limit, :order, :fields, :links, :includes, :conditions
    ]

    attr_reader :resource, :resource_name, *OPTIONS

    def update(other)
      other = self.class.new(resource, other) if other.kind_of?(Hash)

      @resource, @reload = other.resource, other.reload

      @offset = other.offset unless other.offset == 0
      @limit  = other.limit  unless other.limit.nil?

      # if self resource and other resource are the same, then
      # overwrite @order with other order.  If they are different
      # then set @order to the union of other order and @order,
      # with the other order taking precedence
      @order = @resource == other.resource ? other.order : other.order | @order

      @fields   |= other.fields
      @links    |= other.links
      @includes |= other.includes

      update_conditions(other)

      self
    end

    def merge(other)
      self.dup.update(other)
    end

    def ==(other)
      return true if super
      # TODO: add a #hash method, and then use it in the comparison, eg:
      #   return hash == other.hash
      @resource == other.resource &&
      @reload   == other.reload   &&
      @offset   == other.offset   &&
      @limit    == other.limit    &&
      @order    == other.order    &&  # order is significant, so do not sort this
      @fields   == other.fields   &&  # TODO: sort this so even if the order is different, it is equal
      @links    == other.links    &&  # TODO: sort this so even if the order is different, it is equal
      @includes == other.includes &&  # TODO: sort this so even if the order is different, it is equal
      @conditions.sort_by { |c| c[0].hash + c[1].hash + c[2].hash } == other.conditions.sort_by { |c| c[0].hash + c[1].hash + c[2].hash }
    end

    alias eql? ==

    def parameters
      parameters = []
      conditions.each do |tuple|
        parameters << tuple[2] if tuple.size == 3
      end
      parameters
    end

    # find the point in self.conditions where the sub select tuple is
    # located. Delete the tuple and add value.conditions. value must be a
    # <DM::Query>
    #
    def merge_sub_select_conditions(operator, property, value)
      raise ArgumentError.new('+value+ is not a DataMapper::Query') unless value.is_a?(DataMapper::Query)
      new_conditions = []
      conditions.each do |tuple|
        if tuple.length == 3 && tuple[0].to_s == operator.to_s && tuple[1] == property && tuple[2] == value
          value.conditions.each do |sub_select_tuple|
            new_conditions << sub_select_tuple
          end
        else
          new_conditions << tuple
        end
      end
      @conditions = new_conditions
    end

    def debug
      puts "#{@link.inspect}"
    end


    alias reload? reload

    private

    def initialize(resource, options = {})
      validate_resource(resource)
      validate_options(options)

      @repository     = resource.repository
      repository_name = @repository.name
      @resource_name  = resource.resource_name(repository_name)
      @properties     = resource.properties(repository_name)

      @resource   = resource                        # must be Class that includes DM::Resource
      @reload     = options.fetch :reload,   false  # must be true or false
      @offset     = options.fetch :offset,   0      # must be an Integer greater than or equal to 0
      @limit      = options.fetch :limit,    nil    # must be an Integer greater than or equal to 1
      @order      = options.fetch :order,    []     # must be an Array of Symbol, DM::Query::Direction or DM::Property
      @fields     = options.fetch :fields,   @properties.defaults  # must be an Array of Symbol, String or DM::Property
      @links      = options.fetch :links,    []     # must be an Array of Tuples - Tuple [DM::Query,DM::Assoc::Relationship]
      @includes   = options.fetch :includes, []     # must be an Array of Symbol, String, DM::Property 1-jump-away or DM::Query::Path
      @conditions = []                              # must be an Array of triplets (or pairs when passing in raw String queries)

      # normalize order and fields
      normalize_order
      normalize_fields

      # XXX: should I validate that each property in @order corresponds
      # to something in @fields?  Many DB engines require they match,
      # and I can think of no valid queries where a field would be so
      # important that you sort on it, but not important enough to
      # return.

      # normalize links and includes.
      # NOTE: this must be done after order and fields
      normalize_links
      normalize_includes

      # treat all non-options as conditions
      (options.keys - OPTIONS - OPTIONS.map(&:to_s)).each do |k|
        append_condition(k, options[k])
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

    # validate the resource
    def validate_resource(resource)
      raise ArgumentError, "resource must be a Class, but is #{resource.class}" unless resource.kind_of?(Class)
      raise ArgumentError, 'resource must include DataMapper::Resource'         unless resource.included_modules.include?(DataMapper::Resource)
    end

    # validate the options
    def validate_options(options)
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
    # validate other DM::Query or Hash object
    def validate_other(other)
      if other.kind_of?(self.class)
        raise ArgumentError, "other #{self.class} must belong to the same repository" unless other.resource.repository == @resource.repository
      elsif !other.kind_of?(Hash)
        raise ArgumentError, "other must be a #{self.class} or Hash object"
      end
    end

    # normalize order elements to DM::Query::Direction
    def normalize_order
      @order = @order.map do |order_by|
        case order_by
          when Direction
            # NOTE: The property is available via order_by.property
            # TODO: if the Property's resource doesn't match
            # self.resource, append the property's resource to @links
            # eg:
            #if property.resource != self.resource
            #  @links << discover_path_for_property(property)
            #end

            order_by
          when Property
            # TODO: if the Property's resource doesn't match
            # self.resource, append the property's resource to @links
            # eg:
            #if property.resource != self.resource
            #  @links << discover_path_for_property(property)
            #end

            Direction.new(order_by)
          when Symbol, String
            property = @properties[order_by]
            raise ArgumentError, "Order field #{order_by.inspect} does not map to a DataMapper::Property" if property.nil?
            Direction.new(property)
          else
            raise ArgumentError, "Order #{order_by.inspect} not supported"
        end
      end
    end

    # normalize fields to DM::Property
    def normalize_fields
      @fields = @fields.map do |field|
        case field
          when Property
            # TODO: if the Property's resource doesn't match
            # self.resource, append the property's resource to @links
            # eg:
            #if property.resource != self.resource
            #  @links << discover_path_for_property(property)
            #end
            field
          when Symbol, String
            property = @properties.detect(field)
            raise ArgumentError, "Field #{field.inspect} does not map to a DataMapper::Property" if property.nil?
            property
          else
            raise ArgumentError, "Field type #{field.inspect} not supported"
        end
      end
    end

    # normalize links to DM::Associations::Relationship
    def normalize_links
      @links = @links.map do |link|
        case link
          when DataMapper::Associations::Relationship
            link
          when Symbol, String
            link = link.to_sym if link.is_a?(String)
            raise ArgumentError.new("Link #{link}. No such relationship") unless resource.relationships.has_key?(link)
            resource.relationships[link]
          else
            raise ArgumentError.new("Link type #{link.inspect} not supported")
        end
      end
    end

    # normalize includes to DM::Query::Path
    def normalize_includes
      # TODO: normalize Array of Symbol, String, DM::Property 1-jump-away or DM::Query::Path
    end

    def append_condition(property, value)
      operator = :eql

      property = case property
        when DataMapper::Property
          property
        when Operator
          operator = property.type
          @properties.detect(property.to_sym)
        when Symbol, String
          @properties.detect(property)
        else
          raise ArgumentError, "Condition type #{property.inspect} not supported"
      end

      raise ArgumentError, "Clause #{property.inspect} does not map to a DataMapper::Property" if property.nil?

      @conditions << [ operator, property, value ]
    end

    # TODO: check for other mutually exclusive operator + property
    # combinations.  For example if self's conditions were
    # [ :gt, :amount, 5 ] and the other's condition is [ :lt, :amount, 2 ]
    # there is a conflict.  When in conflict the other's conditions
    # overwrites self's conditions.

    # TODO: Another condition is when the other condition operator is
    # eql, this should over-write all the like,range and list operators
    # for the same property, since we are now looking for an exact match.
    # Vice versa, passing in eql should overwrite all of those operators.

    def update_conditions(other)
      # build an index of conditions by the property and operator to
      # avoid nested looping
      conditions_index = Hash.new { |h,k| h[k] = {} }
      @conditions.each do |condition|
        next unless condition.size == 3  # only process triplets
        operator, property = *condition
        conditions_index[property][operator] = condition
      end

      # loop over each of the other's conditions, and overwrite the
      # conditions when in conflict
      other.conditions.each do |other_condition|
        if other_condition.size == 3 # only process triplets
          other_operator, other_property, other_value = *other_condition

          if condition = conditions_index[other_property][other_operator]
            operator, property, value = *condition

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
