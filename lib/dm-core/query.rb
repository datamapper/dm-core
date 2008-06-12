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

      def reverse
        self.class.new(@property, @direction == :asc ? :desc : :asc)
      end

      def inspect
        "#<#{self.class.name} #{@property.inspect} #{@direction}>"
      end

      private

      def initialize(property, direction = :asc)
        raise ArgumentError, "+property+ is not a DataMapper::Property, but was #{property.class}", caller unless property.kind_of?(Property)
        raise ArgumentError, "+direction+ is not a Symbol, but was #{direction.class}", caller             unless direction.kind_of?(Symbol)

        @property  = property
        @direction = direction
      end
    end # class Direction

    class Operator
      attr_reader :target, :operator

      def to_sym
        @property_name
      end

      def ==(other)
        @operator == other.operator && @target == other.target
      end

      private

      def initialize(target, operator)
        unless operator.kind_of?(Symbol)
          raise ArgumentError, "+operator+ is not a Symbol, but was #{type.class}", caller
        end

        @target     = target
        @operator   = operator
      end
    end # class Operator

    class Path

      attr_reader :relationships, :model, :property, :operator


      def initialize(repository, relationships, model, property_name = nil)
        raise ArgumentError, "+repository+ is not a Repository, but was #{repository.class}", caller unless repository.kind_of?(Repository)
        raise ArgumentError, "+relationships+ is not an Array, it is a #{relationships.class}", caller unless relationships.kind_of?(Array)
        raise ArgumentError, "+model+ is not a DM::Resource, it is a #{model}", caller   unless model.ancestors.include?(DataMapper::Resource)
        raise ArgumentError, "+property_name+ is not a Symbol, it is a #{property_name.class}", caller unless property_name.kind_of?(Symbol) || property_name.nil?

        @repository    = repository
        @relationships = relationships
        @model         = model
        @property      = @model.properties(@repository.name)[property_name] if property_name
      end

      [:gt, :gte, :lt, :lte, :not, :eql, :like, :in].each do |sym|

        self.class_eval <<-RUBY
          def #{sym}
            Operator.new(self, :#{sym})
          end
        RUBY

      end

      def method_missing(method, *args)
        if relationship = @model.relationships(@repository.name)[method]
          clazz = if @model == relationship.child_model
           relationship.parent_model
          else
           relationship.child_model
          end
          relations = []
          relations.concat(@relationships)
          relations << relationship #@model.relationships[method]
          return Query::Path.new(@repository, relations,clazz)
        end

        if @model.properties(@model.repository.name)[method]
          @property = @model.properties(@model.repository.name)[method]
          return self
        end
        raise NoMethodError, "undefined property or association `#{method}' on #{@model}"
      end

      # duck type the DM::Query::Path to act like a DM::Property
      def field(*args)
        @property ? @property.field(*args) : nil
      end

    end # class Path

    OPTIONS = [
      :reload, :offset, :limit, :order, :add_reversed, :fields, :links, :includes, :conditions
    ]

    attr_reader :repository, :model, *OPTIONS - [ :reload ]
    attr_writer :add_reversed
    alias add_reversed? add_reversed

    def reload?
      @reload
    end

    def reverse
      dup.reverse!
    end

    def reverse!
      # set the default sort order
      order = normalize_order(self.order.any? ? self.order : model.default_order(repository.name))

      # reverse the sort order
      update(:order => order.map { |o| o.reverse })

      self
    end

    def update(other)
      assert_valid_other(other)

      if other.kind_of?(Hash)
        return self if other.empty?
        other = self.class.new(@repository, model, other)
      end

      return self if self == other

      # TODO: update this so if "other" had a value explicitly set
      #       overwrite the attributes in self

      # only overwrite the attributes with non-default values
      @reload       = other.reload?       unless other.reload?       == false
      @offset       = other.offset        unless other.offset        == 0
      @limit        = other.limit         unless other.limit         == nil
      @order        = other.order         unless other.order         == []
      @add_reversed = other.add_reversed? unless other.add_reversed? == false
      @fields       = other.fields        unless other.fields        == @properties.defaults
      @links        = other.links         unless other.links         == []
      @includes     = other.includes      unless other.includes      == []

      update_conditions(other)

      self
    end

    def merge(other)
      dup.update(other)
    end

    def ==(other)
      return true if super
      return false unless other.kind_of?(self.class)

      # TODO: add a #hash method, and then use it in the comparison, eg:
      #   return hash == other.hash
      @model        == other.model         &&
      @reload       == other.reload?       &&
      @offset       == other.offset        &&
      @limit        == other.limit         &&
      @order        == other.order         &&  # order is significant, so do not sort this
      @add_reversed == other.add_reversed? &&
      @fields       == other.fields        &&  # TODO: sort this so even if the order is different, it is equal
      @links        == other.links         &&  # TODO: sort this so even if the order is different, it is equal
      @includes     == other.includes      &&  # TODO: sort this so even if the order is different, it is equal
      @conditions.sort_by { |c| c.at(0).hash + c.at(1).hash + c.at(2).hash } == other.conditions.sort_by { |c| c.at(0).hash + c.at(1).hash + c.at(2).hash }
    end

    alias eql? ==

    def bind_values
      bind_values = []
      conditions.each do |tuple|
        next if tuple.size == 2
        operator, property, bind_value = *tuple
        if :raw == operator
          bind_values.push(*bind_value)
        else
          bind_values << bind_value
        end
      end
      bind_values
    end

    # TODO: spec this
    def inheritance_property_index(repository)
      fields.index(model.inheritance_property(repository.name))
    end

    # TODO: spec this
    def key_property_indexes(repository)
      if (key_property_indexes = model.key(repository.name).map { |property| fields.index(property) }).all?
        key_property_indexes
      end
    end

    # find the point in self.conditions where the sub select tuple is
    # located. Delete the tuple and add value.conditions. value must be a
    # <DM::Query>
    #
    def merge_subquery(operator, property, value)
      raise ArgumentError, "+value+ is not a #{self.class}, but was #{value.class}", caller unless value.kind_of?(self.class)

      new_conditions = []
      conditions.each do |tuple|
        if tuple.at(0).to_s == operator.to_s && tuple.at(1) == property && tuple.at(2) == value
          value.conditions.each do |subquery_tuple|
            new_conditions << subquery_tuple
          end
        else
          new_conditions << tuple
        end
      end
      @conditions = new_conditions
    end

    def inspect
      attrs = [
        [ :repository, repository.name ],
        [ :model,      model           ],
        [ :fields,     fields          ],
        [ :links,      links           ],
        [ :conditions, conditions      ],
        [ :order,      order           ],
        [ :limit,      limit           ],
        [ :offset,     offset          ],
        [ :reload,     reload?         ],
      ]

      "#<#{self.class.name} #{attrs.map { |(k,v)| "@#{k}=#{v.inspect}" } * ' '}>"
    end

    private

    def initialize(repository, model, options = {})
      raise TypeError, "+repository+ must be a Repository, but is #{repository.class}" unless repository.kind_of?(Repository)

      options.each_pair { |k,v| options[k] = v.call if v.is_a? Proc } if options.is_a? Hash

      assert_valid_model(model)
      assert_valid_options(options)

      @repository = repository
      @properties = model.properties(@repository.name)

      @model        = model                               # must be Class that includes DM::Resource
      @reload       = options.fetch :reload,       false  # must be true or false
      @offset       = options.fetch :offset,       0      # must be an Integer greater than or equal to 0
      @limit        = options.fetch :limit,        nil    # must be an Integer greater than or equal to 1
      @order        = options.fetch :order,        []     # must be an Array of Symbol, DM::Query::Direction or DM::Property
      @add_reversed = options.fetch :add_reversed, false  # must be true or false
      @fields       = options.fetch :fields,       @properties.defaults  # must be an Array of Symbol, String or DM::Property
      @links        = options.fetch :links,        []     # must be an Array of Tuples - Tuple [DM::Query,DM::Assoc::Relationship]
      @includes     = options.fetch :includes,     []     # must be an Array of DM::Query::Path
      @conditions   = []                                  # must be an Array of triplets (or pairs when passing in raw String queries)

      # normalize order and fields
      @order  = normalize_order(@order)
      @fields = normalize_fields(@fields)

      # XXX: should I validate that each property in @order corresponds
      # to something in @fields?  Many DB engines require they match,
      # and I can think of no valid queries where a field would be so
      # important that you sort on it, but not important enough to
      # return.

      # normalize links and includes.
      # NOTE: this must be done after order and fields
      @links    = normalize_links(@links)
      @includes = normalize_includes(@includes)

      translate_custom_types(@properties, options)

      # treat all non-options as conditions
      (options.keys - OPTIONS - OPTIONS.map { |option| option.to_s }).each do |k|
        append_condition(k, options[k])
      end

      # parse raw options[:conditions] differently
      if conditions = options[:conditions]
        if conditions.kind_of?(Array)
          raw_query, *bind_values = conditions
          @conditions << if bind_values.empty?
            [ :raw, raw_query ]
          else
            [ :raw, raw_query, bind_values ]
          end
        end
      end

      # freeze the internal attributes
      OPTIONS.each do |attribute|
        instance_variable_get("@#{attribute}").freeze
      end

#      freeze
    end

    def initialize_copy(original)
      # deep-copy the condition tuples when copying the object
      @conditions = original.conditions.map { |tuple| tuple.dup }
    end

    def translate_custom_types(properties, options)
      options.each do |key, value|
        case key
          when DataMapper::Query::Operator
            options[key] = properties[key.target].type.dump(value, properties[key.target]) if !properties[key.target].nil? && properties[key.target].custom?
          when Symbol, String
            options[key] = properties[key].type.dump(value, properties[key]) if !properties[key].nil? && properties[key].custom?
        end
      end
    end

    # validate the model
    def assert_valid_model(model)
      raise ArgumentError, "+model+ must be a Class, but is #{model.class}" unless model.kind_of?(Class)
      raise ArgumentError, "+model+ must include DataMapper::Resource"      unless model.ancestors.include?(Resource)
    end

    # validate the options
    def assert_valid_options(options)
      raise ArgumentError, "+options+ must be a Hash, but was #{options.class}" unless options.kind_of?(Hash)

      # validate the reload option
      if options.has_key?(:reload) && options[:reload] != true && options[:reload] != false
        raise ArgumentError, "+options[:reload]+ must be true or false, but was #{options[:reload].inspect}"
      end

      # validate the offset and limit options
      ([ :offset, :limit ] & options.keys).each do |attribute|
        value = options[attribute]
        raise ArgumentError, "+options[:#{attribute}]+ must be an Integer, but was #{value.class}" unless value.kind_of?(Integer)
      end
      raise ArgumentError, "+options[:offset]+ must be greater than or equal to 0, but was #{options[:offset].inspect}" if options.has_key?(:offset) && !(options[:offset] >= 0)
      raise ArgumentError, "+options[:limit]+ must be greater than or equal to 1, but was #{options[:limit].inspect}"   if options.has_key?(:limit)  && !(options[:limit]  >= 1)

      # validate the order, fields, links, includes and conditions options
      ([ :order, :fields, :links, :includes, :conditions ] & options.keys).each do |attribute|
        value = options[attribute]
        raise ArgumentError, "+options[:#{attribute}]+ must be an Array, but was #{value.class}" unless value.kind_of?(Array)
        raise ArgumentError, "+options[:#{attribute}]+ cannot be empty"                          unless value.any?
      end
    end

    # validate other DM::Query or Hash object
    def assert_valid_other(other)
      if other.kind_of?(self.class)
        raise ArgumentError, "+other+ #{self.class} must be for the #{repository.name} repository, not #{other.repository.name}" unless other.repository == repository
        raise ArgumentError, "+other+ #{self.class} must be for the #{model.name} model, not #{other.model.name}"                unless other.model      == model
      elsif !other.kind_of?(Hash)
        raise ArgumentError, "+other+ must be a #{self.class} or Hash, but was a #{other.class}"
      end
    end

    # normalize order elements to DM::Query::Direction
    def normalize_order(order)
      order.map do |order_by|
        case order_by
          when Direction
            # NOTE: The property is available via order_by.property
            # TODO: if the Property's model doesn't match
            # self.model, append the property's model to @links
            # eg:
            #if property.model != self.model
            #  @links << discover_path_for_property(property)
            #end

            order_by
          when Property
            # TODO: if the Property's model doesn't match
            # self.model, append the property's model to @links
            # eg:
            #if property.model != self.model
            #  @links << discover_path_for_property(property)
            #end

            Direction.new(order_by)
          when Operator
            property = @properties[order_by.target]
            Direction.new(property, order_by.operator)
          when Symbol, String
            property = @properties[order_by]
            raise ArgumentError, "+options[:order]+ entry #{order_by} does not map to a DataMapper::Property" if property.nil?
            Direction.new(property)
          else
            raise ArgumentError, "+options[:order]+ entry #{order_by.inspect} not supported"
        end
      end
    end

    # normalize fields to DM::Property
    def normalize_fields(fields)
      # TODO: return a PropertySet
      fields.map do |field|
        case field
          when Property
            # TODO: if the Property's model doesn't match
            # self.model, append the property's model to @links
            # eg:
            #if property.model != self.model
            #  @links << discover_path_for_property(property)
            #end
            field
          when Symbol, String
            property = @properties[field]
            raise ArgumentError, "+options[:fields]+ entry #{field} does not map to a DataMapper::Property" if property.nil?
            property
          else
            raise ArgumentError, "+options[:fields]+ entry #{field.inspect} not supported"
        end
      end
    end

    # normalize links to DM::Query::Path
    def normalize_links(links)
      # XXX: this should normalize to DM::Query::Path, not DM::Association::Relationship
      # because a link may be more than one-hop-away from the source.  A DM::Query::Path
      # should include an Array of Relationship objects that trace the "path" between
      # the source and the target.
      links.map do |link|
        case link
          when Associations::Relationship
            link
          when Symbol, String
            link = link.to_sym if link.kind_of?(String)
            raise ArgumentError, "+options[:links]+ entry #{link} does not map to a DataMapper::Associations::Relationship" unless model.relationships(@repository.name).has_key?(link)
            model.relationships(@repository.name)[link]
          else
            raise ArgumentError, "+options[:links]+ entry #{link.inspect} not supported"
        end
      end
    end

    # normalize includes to DM::Query::Path
    def normalize_includes(includes)
      # TODO: normalize Array of Symbol, String, DM::Property 1-jump-away or DM::Query::Path
      # NOTE: :includes can only be and array of DM::Query::Path objects now. This method
      #       can go away after review of what has been done.
      includes
    end

    # validate that all the links or includes are present for the given DM::Query::Path
    #
    def validate_query_path_links(path)
      path.relationships.map do |relationship|
        @links << relationship unless (@links.include?(relationship) || @includes.include?(relationship))
      end
    end

    def append_condition(clause, bind_value)
      operator = :eql
      bind_value = bind_value.call if bind_value.is_a?(Proc)

      property = case clause
        when Property
          clause
        when Query::Path
          validate_query_path_links(clause)
          clause
        when Operator
          operator = clause.operator
          if clause.target.is_a?(Symbol)
            @properties[clause.target]
          elsif clause.target.is_a?(Query::Path)
            validate_query_path_links(clause.target)
            clause.target
          end
        when Symbol
          @properties[clause]
        when String
          if clause =~ /\w\.\w/
            query_path = @model
            clause.split(".").each { |piece| query_path = query_path.send(piece) }
            append_condition(query_path, bind_value)
            return
          else
            @properties[clause]
          end
        else
          raise ArgumentError, "Condition type #{clause.inspect} not supported"
      end

      raise ArgumentError, "Clause #{clause.inspect} does not map to a DataMapper::Property" if property.nil?

      @conditions << [ operator, property, bind_value ]
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
      @conditions = @conditions.dup

      # build an index of conditions by the property and operator to
      # avoid nested looping
      conditions_index = Hash.new { |h,k| h[k] = {} }
      @conditions.each do |condition|
        operator, property = *condition
        next if :raw == operator
        conditions_index[property][operator] = condition
      end

      # loop over each of the other's conditions, and overwrite the
      # conditions when in conflict
      other.conditions.each do |other_condition|
        other_operator, other_property, other_bind_value = *other_condition

        unless :raw == other_operator
          if condition = conditions_index[other_property][other_operator]
            operator, property, bind_value = *condition

            next if bind_value == other_bind_value

            # overwrite the bind value in the existing condition
            condition[2] = case operator
              when :eql, :like then other_bind_value
              when :gt,  :gte  then [ bind_value, other_bind_value ].min
              when :lt,  :lte  then [ bind_value, other_bind_value ].max
              when :not, :in
                if bind_value.kind_of?(Array)
                  bind_value |= other_bind_value
                elsif other_bind_value.kind_of?(Array)
                  other_bind_value |= bind_value
                else
                  other_bind_value
                end
            end

            next  # process the next other condition
          end
        end

        # otherwise append the other condition
        @conditions << other_condition.dup
      end

      @conditions.freeze
    end
  end # class Query
end # module DataMapper
