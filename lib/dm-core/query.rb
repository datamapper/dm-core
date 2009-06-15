# TODO: break this up into classes for each primary option, eg:
#
#   - DataMapper::Query::Fields
#   - DataMapper::Query::Links
#   - DataMapper::Query::Conditions
#   - DataMapper::Query::Offset
#   - DataMapper::Query::Limit
#   - DataMapper::Query::Order
#
# TODO: move assertions, validations, transformations, and equality
#   checking into each class and clean up Query
#
# TODO: add a way to "register" these classes with the Query object
#   so that new reserved options can be added in the future.  Each
#   class will need to implement a "slug" method or something similar
#   so that their option namespace can be reserved.

# TODO: move condition transformations into a Query::Conditions
#   helper class that knows how to transform the primitives, and
#   calls #comparison_for(repository, model) on objects (or some
#   other convention that we establish)

module DataMapper

  # Query class represents a query which will be run against the data-store.
  # Generally Query objects can be found inside Collection objects.
  #
  class Query
    include Extlib::Assertions

    OPTIONS = [ :fields, :links, :conditions, :offset, :limit, :order, :unique, :add_reversed, :reload ].to_set.freeze

    ##
    # Returns the repository query should be
    # executed in
    #
    # Set in cases like the following:
    #
    # @example
    #
    #   Document.all(:repository => :medline)
    #
    #
    # @return [Repository]
    #   the Repository to retrieve results from
    #
    # @api semipublic
    attr_reader :repository

    ##
    # Returns model (class) that is used
    # to instantiate objects from query result
    # returned by adapter
    #
    # @return [Model]
    #   the Model to retrieve results from
    #
    # @api semipublic
    attr_reader :model

    ##
    # Returns the fields
    #
    # Set in cases like the following:
    #
    # @example
    #
    #   Document.all(:fields => [:title, :vernacular_title, :abstract])
    #
    # @return [PropertySet]
    #   the properties in the Model that will be retrieved
    #
    # @api semipublic
    attr_reader :fields

    ##
    # Returns the links (associations) query fetches
    #
    # @return [Array<DataMapper::Associations::Relationship>]
    #   the relationships that will be used to scope the results
    #
    # @api semipublic
    attr_reader :links

    ##
    # Returns the conditions of the query
    #
    # In the following example:
    #
    # @example
    #
    #   Team.all(:wins.gt => 30, :conference => 'East')
    #
    # Conditions are "greater than" operator for "wins"
    # field and exact match operator for "conference".
    #
    # @return [Array]
    #   the conditions that will be used to scope the results
    #
    # @api semipublic
    attr_reader :conditions

    ##
    # Returns the offset query uses
    #
    # Set in cases like the following:
    #
    # @example
    #
    #   Document.all(:offset => page.offset)
    #
    # @return [Integer]
    #   the offset of the results
    #
    # @api semipublic
    attr_reader :offset

    ##
    # Returns the limit query uses
    #
    # Set in cases like the following:
    #
    # @example
    #
    #   Document.all(:limit => 10)
    #
    # @return [Integer, NilClass]
    #   the maximum number of results
    #
    # @api semipublic
    attr_reader :limit

    ##
    # Returns the order
    #
    # Set in cases like the following:
    #
    # @example
    #
    #   Document.all(:order => [:created_at.desc, :length.desc])
    #
    # query order is a set of two ordering rules, descending on
    # "created_at" field and descending again on "length" field
    #
    # @return [Array]
    #   the order of results
    #
    # @api semipublic
    attr_reader :order

    ##
    # Returns the original options
    #
    # @return [Hash]
    #   the original options
    #
    # @api private
    attr_reader :options

    ##
    # Indicates if each result should be returned in reverse order
    #
    # Set in cases like the following:
    #
    # @example
    #
    #   Document.all(:limit => 5).reverse
    #
    # Note that :add_reversed option may be used in conditions directly,
    # but this is rarely the case
    #
    # @return [TrueClass, FalseClass]
    #   true if the results should be reversed, false if not
    #
    # @api private
    def add_reversed?
      @add_reversed
    end

    ##
    # Indicates if the Query results should replace the results in the Identity Map
    #
    #   TODO: needs example
    #
    # @return [TrueClass, FalseClass]
    #   true if the results should be reloaded, false if not
    #
    # @api semipublic
    def reload?
      @reload
    end

    ##
    # Indicates if the Query results should be unique
    #
    #   TODO: needs example
    #
    # @return [TrueClass, FalseClass]
    #   true if the results should be unique, false if not
    #
    # @api semipublic
    def unique?
      @unique
    end

    ##
    # Indicates if the Query has raw conditions
    #
    # @return [TrueClass, FalseClass]
    #   true if the query has raw conditions, false if not
    #
    # @api semipublic
    def raw?
      @raw
    end

    ##
    # Indicates if the Query is valid
    #
    # @return [TrueClass, FalseClass]
    #   true if the query is valid
    #
    # @api semipublic
    def valid?
      conditions.valid?
    end

    ##
    # Returns a new Query with a reversed order
    #
    # @example
    #
    #   Document.all(:limit => 5).reverse
    #
    # Will execute a single query with correct order
    #
    # @return [Query]
    #   new Query with reversed order
    #
    # @api semipublic
    def reverse
      dup.reverse!
    end

    ##
    # Reverses the sort order of the Query
    #
    # @example
    #
    #   Document.all(:limit => 5).reverse
    #
    # Will execute a single query with original order
    # and then reverse collection in the Ruby space
    #
    # @return [Query]
    #   self
    #
    # @api semipublic
    def reverse!
      # reverse the sort order
      @order.map! { |direction| direction.reverse! }

      # copy the order to the options
      @options = @options.merge(:order => @order.map { |direction| direction.dup }).freeze

      self
    end

    ##
    # Updates the Query with another Query or conditions
    #
    # Pretty unrealistic example:
    #
    # @example
    #
    #   Journal.all(:limit => 2).query.limit                     # => 2
    #   Journal.all(:limit => 2).query.update(:limit => 3).limit # => 3
    #
    # @param [Query, Hash] other
    #   other Query or conditions
    #
    # @return [Query]
    #   self
    #
    # @api semipublic
    def update(other)
      assert_kind_of 'other', other, self.class, Hash

      options = case other
        when self.class
          if self.eql?(other)
            return self
          end

          assert_valid_other(other)

          @options.merge(other.options)

        when Hash
          if other.empty?
            return self
          end

          @options.merge(other)
      end

      initialize(repository, model, options)

      self
    end

    ##
    # Similar to Query#update, but acts on a duplicate.
    #
    # @param [Query, Hash] other
    #   other query to merge with
    #
    # @return [Query]
    #   updated duplicate of original query
    #
    # @api semipublic
    def merge(other)
      dup.update(other)
    end

    # Builds and returns new query that merges
    # original with one given, and slices the result
    # with respect to :limit and :offset options
    #
    # This method is used by Collection to
    # concatenate options from multiple chained
    # calls in cases like the following:
    #
    # @example
    #
    #   author.books.all(:year => 2009).all(:published => false)
    #
    # @api semipublic
    def relative(options)
      assert_kind_of 'options', options, Hash

      options = options.dup

      repository = options.delete(:repository) || self.repository

      if repository.kind_of?(Symbol)
        repository = DataMapper.repository(repository)
      end

      if options.key?(:offset) && (options.key?(:limit) || self.limit)
        offset = options.delete(:offset)
        limit  = options.delete(:limit) || self.limit - offset

        self.class.new(repository, model, @options.merge(options)).slice!(offset, limit)
      else
        self.class.new(repository, model, @options.merge(options))
      end
    end

    ##
    # Takes an Enumerable of records, and destructively filters it.
    # First finds all matching conditions, then sorts it,
    # then does offset & limit
    #
    # @param [Enumerable] records
    #   The set of records to be filtered
    #
    # @return [Enumerable]
    #   Whats left of the given array after the filtering
    #
    # @api semipublic
    def filter_records(records)
      records = records.uniq if unique?
      records = match_records(records)
      records = sort_records(records)
      records = limit_records(records)
      records
    end

    ##
    # Filter a set of records by the conditions
    #
    # @param [Enumerable] records
    #   The set of records to be filtered
    #
    # @return [Enumerable]
    #   Whats left of the given array after the matching
    #
    # @api semipublic
    def match_records(records)
      records.select do |record|
        conditions.matches?(record)
      end
    end

    ##
    # Sorts a list of Records by the order
    #
    # @param [Enumerable] records
    #   A list of Resources to sort
    #
    # @return [Enumerable]
    #   The sorted records
    #
    # @api semipublic
    def sort_records(records)
      sort_order = order.map { |direction| [ direction.target, direction.operator == :asc ] }

      records.sort_by do |record|
        sort_order.map do |(property, ascending)|
          Sort.new(record_value(record, property), ascending)
        end
      end
    end

    ##
    # Limits a set of records by the offset and/or limit
    #
    # @param [Enumerable] records
    #   A list of Recrods to sort
    #
    # @return [Enumerable]
    #   The offset & limited records
    #
    # @api semipublic
    def limit_records(records)
      size = records.size

      if offset > size - 1
        []
      elsif (limit && limit != size) || offset > 0
        records[offset, limit || size] || []
      else
        records.dup
      end
    end

    ##
    # Compares another Query for equivalency
    #
    # @param [Query] other
    #   the other Query to compare with
    #
    # @return [TrueClass, FalseClass]
    #   true if they are equivalent, false if not
    #
    # @api semipublic
    def ==(other)
      if equal?(other)
        return true
      end

      unless [ :repository, :model, :fields, :links, :conditions, :order, :offset, :limit, :reload?, :unique?, :add_reversed? ].all? { |method| other.respond_to?(method) }
        return false
      end

      cmp?(other, :==)
    end

    ##
    # Compares another Query for equality
    #
    # @param [Query] other
    #   the other Query to compare with
    #
    # @return [TrueClass, FalseClass]
    #   true if they are equal, false if not
    #
    # @api semipublic
    def eql?(other)
      if equal?(other)
        return true
      end

      unless other.instance_of?(self.class)
        return false
      end

      cmp?(other, :eql?)
    end

    # Slices collection by adding limit and offset to the
    # query, so a single query is executed
    #
    # @example
    #
    #   Journal.all(:limit => 10).slice(3, 5)
    #
    # will execute query with the following limit and offset
    # (when repository uses DataObjects adapter, and thus
    # queries use SQL):
    #
    #   LIMIT 5 OFFSET 3
    #
    # @api semipublic
    def slice(*args)
      dup.slice!(*args)
    end

    alias [] slice

    # Slices collection by adding limit and offset to the
    # query, so a single query is executed
    #
    # @example
    #
    #   Journal.all(:limit => 10).slice!(3, 5)
    #
    # will execute query with the following limit
    # (when repository uses DataObjects adapter, and thus
    # queries use SQL):
    #
    #   LIMIT 10
    #
    # and then takes a slice of collection in the Ruby space
    #
    # @api semipublic
    def slice!(*args)
      offset, limit = extract_slice_arguments(*args)

      if self.limit || self.offset > 0
        offset, limit = get_relative_position(offset, limit)
      end

      update(:offset => offset, :limit => limit)
    end

    # Returns detailed human readable
    # string representation of the query
    #
    # @return [String]  detailed string representation of the query
    #
    # @api semipublic
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
        [ :unique,     unique?         ],
      ]

      "#<#{self.class.name} #{attrs.map { |key, value| "@#{key}=#{value.inspect}" }.join(' ')}>"
    end

    ##
    # Get the properties used in the conditions
    #
    # @return [Set<Property>]
    #  Set of properties used in the conditions
    #
    # @api private
    def condition_properties
      properties = Set.new

      each_comparison do |comparison|
        properties << comparison.subject if comparison.subject.kind_of?(Property)
      end

      properties
    end

    private

    ##
    # Initializes a Query instance
    #
    # @example
    #
    #  JournalIssue.all(:links => [:journal, :country, :medium], :repository => :medline)
    #
    # initialized a query with repository defined with name :medline,
    # model JournalIssue and options { :links => [:journal, :country, :medium] }
    #
    # @param [Repository] repository
    #   the Repository to retrieve results from
    # @param [Model] model
    #   the Model to retrieve results from
    # @param [Hash] options
    #   the conditions and scope
    #
    # @api semipublic
    def initialize(repository, model, options = {})
      assert_kind_of 'repository', repository, Repository
      assert_kind_of 'model',      model,      Model

      @repository = repository
      @model      = model
      @options    = options.dup.freeze

      repository_name = repository.name

      @properties    = @model.properties(repository_name)
      @relationships = @model.relationships(repository_name)

      assert_valid_options(@options)

      @fields       = @options.fetch :fields,       @properties.defaults
      @links        = @options.fetch :links,        []
      @conditions   = Conditions::Operation.new(:and)  # AND all the conditions together
      @offset       = @options.fetch :offset,       0
      @limit        = @options.fetch :limit,        nil
      @order        = @options.fetch :order,        @model.default_order(repository_name)
      @unique       = @options.fetch :unique,       false
      @add_reversed = @options.fetch :add_reversed, false
      @reload       = @options.fetch :reload,       false
      @raw          = false

      @links = @links.dup

      # treat all non-options as conditions
      @options.except(*OPTIONS).each { |kv| append_condition(*kv) }

      # parse @options[:conditions] differently
      case conditions = @options[:conditions]
        when Conditions::AbstractOperation
          @conditions << conditions

        when Hash
          conditions.each { |kv| append_condition(*kv) }

        when Array
          statement, *bind_values = *conditions
          @conditions << [ statement, bind_values ]
          @raw = true
      end

      normalize_order
      normalize_fields
      normalize_links
    end

    ##
    # Copying contructor, called for Query#dup
    #
    # @api semipublic
    def initialize_copy(original)
      initialize(original.repository, original.model, original.options)
    end

    ##
    # Validate the options
    #
    # @param [#each] options
    #   the options to validate
    #
    # @raise [ArgumentError]
    #   if any pairs in +options+ are invalid options
    #
    # @api private
    def assert_valid_options(options)
      assert_kind_of 'options', options, Hash

      options.each do |attribute, value|
        case attribute
          when :fields                         then assert_valid_fields(value, options[:unique])
          when :links                          then assert_valid_links(value)
          when :conditions                     then assert_valid_conditions(value)
          when :offset                         then assert_valid_offset(value, options[:limit])
          when :limit                          then assert_valid_limit(value)
          when :order                          then assert_valid_order(value, options[:fields])
          when :unique, :add_reversed, :reload then assert_valid_boolean("options[:#{attribute}]", value)
          else
            assert_valid_conditions(attribute => value)
        end
      end
    end

    # Verifies that value of :fields option
    # refers to existing properties
    #
    # @api private
    def assert_valid_fields(fields, unique)
      assert_kind_of 'options[:fields]', fields, Array

      if fields.empty? && unique == false
        raise ArgumentError, '+options[:fields]+ should not be empty if +options[:unique]+ is false'
      end

      fields.each do |field|
        case field
          when Symbol, String
            unless @properties.named?(field)
              raise ArgumentError, "+options[:fields]+ entry #{field.inspect} does not map to a property in #{model}"
            end

          when Property
            unless field.model == model && @properties.include?(field)
              raise ArgumentError, "+options[:field]+ entry #{field.name.inspect} does not map to a property in #{model}"
            end

          else
            raise ArgumentError, "+options[:fields]+ entry #{field.inspect} of an unsupported object #{field.class}"
        end
      end
    end

    # Verifies that value of :links option
    # refers to existing associations
    #
    # @api private
    def assert_valid_links(links)
      assert_kind_of 'options[:links]', links, Array

      if links.empty?
        raise ArgumentError, '+options[:links]+ should not be empty'
      end

      links.each do |link|
        case link
          when Symbol, String
            unless @relationships.key?(link.to_sym)
              raise ArgumentError, "+options[:links]+ entry #{link.inspect} does not map to a relationship in #{model}"
            end

          when Associations::Relationship
            # TODO: figure out how to validate links from other models
            #unless @relationships.value?(link)
            #  raise ArgumentError, "+options[:links]+ entry #{link.name.inspect} does not map to a relationship in #{model}"
            #end

          else
            raise ArgumentError, "+options[:links]+ entry #{link.inspect} of an unsupported object #{link.class}"
        end
      end
    end

    # Verifies that value of :conditions option
    # refers to existing properties
    #
    # @api private
    def assert_valid_conditions(conditions)
      assert_kind_of 'options[:conditions]', conditions, Conditions::AbstractOperation, Hash, Array

      case conditions
        when Hash
          conditions.each do |subject, bind_value|
            case subject
              when Symbol, String
                unless subject.to_s.include?('.') || @properties.named?(subject) || @relationships.key?(subject)
                  raise ArgumentError, "condition #{subject.inspect} does not map to a property or relationship in #{model}"
                end

              when Operator
                unless (Conditions::Comparison.slugs | [ :not ]).include?(subject.operator)
                  raise ArgumentError, "condition #{subject.inspect} used an invalid operator #{subject.operator}"
                end

                assert_valid_conditions(subject.target => bind_value)

                if subject.operator == :not && bind_value.kind_of?(Array) && bind_value.empty?
                  raise ArgumentError, "Cannot use 'not' operator with a bind value that is an empty Array for #{subject.inspect}"
                end

              when Path
                assert_valid_links(subject.relationships)

              when Associations::Relationship, Property
                # TODO: validate that it belongs to the current model, or to any
                # model in the links
                #unless @properties.include?(subject)
                #  raise ArgumentError, "condition #{subject.name.inspect} does not map to a property in #{model}"
                #end

              else
                raise ArgumentError, "condition #{subject.inspect} of an unsupported object #{subject.class}"
            end
          end

        when Array
          if conditions.empty?
            raise ArgumentError, '+options[:conditions]+ should not be empty'
          end

          unless conditions.first.kind_of?(String) && !conditions.first.blank?
            raise ArgumentError, '+options[:conditions]+ should have a statement for the first entry'
          end
      end
    end

    # Verifies that query offset is non-negative and only used together with limit
    # @api private
    def assert_valid_offset(offset, limit)
      assert_kind_of 'options[:offset]', offset, Integer

      unless offset >= 0
        raise ArgumentError, "+options[:offset]+ must be greater than or equal to 0, but was #{offset.inspect}"
      end

      if offset > 0 && limit.nil?
        raise ArgumentError, '+options[:offset]+ cannot be greater than 0 if limit is not specified'
      end
    end

    # Verifies that query limit equals to or greater than 1
    # @api private
    def assert_valid_limit(limit)
      assert_kind_of 'options[:limit]', limit, Integer

      unless limit >= 1
        raise ArgumentError, "+options[:limit]+ must be greater than or equal to 1, but was #{limit.inspect}"
      end
    end

    # Verifies that :order option uses proper operator and refers
    # to existing property
    #
    # @api private
    def assert_valid_order(order, fields)
      assert_kind_of 'options[:order]', order, Array

      if order.empty? && fields && fields.any? { |property| !property.kind_of?(Operator) }
        raise ArgumentError, '+options[:order]+ should not be empty if +options[:fields] contains a non-operator'
      end

      order.each do |order_entry|
        case order_entry
          when Operator
            unless order_entry.operator == :asc || order_entry.operator == :desc
              raise ArgumentError, "+options[:order]+ entry #{order_entry.inspect} used an invalid operator #{order_entry.operator}"
            end

            assert_valid_order([ order_entry.target ], fields)

          when Symbol, String
            unless @properties.named?(order_entry)
              raise ArgumentError, "+options[:order]+ entry #{order_entry.inspect} does not map to a property in #{model}"
            end

          when Property
            unless order_entry.model == model && @properties.include?(order_entry)
              raise ArgumentError, "+options[:order]+ entry #{order_entry.name.inspect} does not map to a property in #{model}"
            end

          when Direction
            unless order_entry.property.model == model && @properties.include?(order_entry.property)
              raise ArgumentError, "+options[:order]+ entry #{order_entry.property.name.inspect} does not map to a property in #{model}"
            end

          else
            raise ArgumentError, "+options[:order]+ entry #{order_entry.inspect} of an unsupported object #{order_entry.class}"
        end
      end
    end

    # Used to verify value of boolean properties in conditions
    # @api private
    def assert_valid_boolean(name, value)
      if value != true && value != false
        raise ArgumentError, "+#{name}+ should be true or false, but was #{value.inspect}"
      end
    end

    # Verifies that associations given in conditions belong
    # to the same repository as query's model
    #
    # @api private
    def assert_valid_other(other)
      unless other.repository == repository
        raise ArgumentError, "+other+ #{self.class} must be for the #{repository.name} repository, not #{other.repository.name}"
      end

      unless other.model == model
        raise ArgumentError, "+other+ #{self.class} must be for the #{model.name} model, not #{other.model.name}"
      end
    end

    ##
    # Normalize order elements to Query::Direction instances
    #
    #   TODO: needs example
    #
    # @api private
    def normalize_order
      # TODO: should Query::Path objects be permitted?  If so, then it
      # should probably be normalized to a Direction object
      @order = @order.map do |order|
        case order
          when Operator
            target   = order.target
            property = target.kind_of?(Property) ? target : @properties[target]

            Direction.new(property, order.operator)

          when Symbol, String
            Direction.new(@properties[order])

          when Property
            Direction.new(order)

          when Direction
            order.dup
        end
      end
    end

    ##
    # Normalize fields to Property instances
    #
    #   TODO: needs example
    #
    # @api private
    def normalize_fields
      @fields = @fields.map do |field|
        case field
          when Symbol, String
            @properties[field]

          when Property, Operator
            field
        end
      end
    end

    ##
    # Normalize links to Query::Path
    #
    # Normalization means links given as symbols are replaced with
    # relationships they refer to, intermediate links are "followed"
    # and duplicates are removed
    #
    # This method, even though is not a bang method, modifies
    # receiver's links attribute
    #
    # @api private
    def normalize_links
      @links.map! do |link|
        relationship = case link
          when Symbol, String             then @relationships[link]
          when Associations::Relationship then link
        end

        if relationship.respond_to?(:links)
          relationship.links
        else
          relationship
        end
      end

      @links.flatten!
      @links.uniq!
    end

    ##
    # Append conditions to this Query
    #
    #   TODO: needs example
    #
    # @param [Property, Symbol, String, Operator, Associations::Relationship, Path] subject
    #   the subject to match
    # @param [Object] bind_value
    #   the value to match on
    # @param [Symbol] operator
    #   the operator to match with
    #
    # @return [Query::Conditions::AbstractOperation]
    #   the Query conditions
    #
    # @api private
    def append_condition(subject, bind_value, operator = :eql)
      case subject
        when Property, Associations::Relationship then append_property_condition(subject, bind_value, operator)
        when Symbol                               then append_symbol_condition(subject, bind_value, operator)
        when String                               then append_string_condition(subject, bind_value, operator)
        when Operator                             then append_operator_conditions(subject, bind_value)
        when Path                                 then append_path(subject, bind_value, operator)
        else
          raise ArgumentError, "#{subject} is an invalid instance: #{subject.class}"
      end
    end

    # TODO: document
    # @api private
    def append_property_condition(property, bind_value, operator)
      bind_value = normalize_bind_value(property, bind_value)
      negated    = operator == :not

      if operator == :eql || negated
        operator = case bind_value
          when Array, Range, Set then :in
          when Regexp            then :regexp
          else                        :eql
        end
      end

      condition = Conditions::Comparison.new(operator, property, bind_value)

      if negated
        condition = Conditions::Operation.new(:not, condition)
      end

      @conditions << condition
    end

    # TODO: document
    # @api private
    def append_symbol_condition(symbol, bind_value, operator)
      append_condition(symbol.to_s, bind_value, operator)
    end

    # TODO: document
    # @api private
    def append_string_condition(string, bind_value, operator)
      if string.include?('.')
        query_path = model
        string.split('.').each { |method| query_path = query_path.send(method) }

        append_condition(query_path, bind_value, operator)
      else
        append_condition(@properties[string] || @relationships[string], bind_value, operator)
      end
    end

    # TODO: document
    # @api private
    def append_operator_conditions(operator, bind_value)
      append_condition(operator.target, bind_value, operator.operator)
    end

    # TODO: document
    # @api private
    def append_path(path, bind_value, operator)
      @links.concat(path.relationships)
      append_condition(path.property, bind_value, operator)
    end

    # TODO: make this typecast all bind values that do not match the
    # property primitive

    # TODO: document
    # @api private
    def normalize_bind_value(property_or_path, bind_value)
      if bind_value.kind_of?(Proc)
        bind_value = bind_value.call
      end

      case property_or_path
        when Property
          if property_or_path.custom?
            bind_value = property_or_path.type.dump(bind_value, property_or_path)
          end

        when Path
          bind_value = normalize_bind_value(property_or_path.property, bind_value)
      end

      # TODO: update InclusionComparison so it knows how to do this
      if bind_value.kind_of?(Array)
        bind_value.uniq!
        bind_value.size == 1 ? bind_value.first : bind_value.sort_by { |value| Sort.new(value) }
      else
        bind_value
      end
    end

    ##
    # Extract arguments for #slice and #slice! then return offset and limit
    #
    # @param [Integer, Array(Integer), Range] *args the offset,
    #   offset and limit, or range indicating first and last position
    #
    # @return [Integer] the offset
    # @return [Integer, NilClass] the limit, if any
    #
    # @api private
    def extract_slice_arguments(*args)
      first_arg, second_arg = args

      if args.size == 2 && first_arg.kind_of?(Integer) && second_arg.kind_of?(Integer)
        return first_arg, second_arg
      elsif args.size == 1
        if first_arg.kind_of?(Integer)
          return first_arg, 1
        elsif first_arg.kind_of?(Range)
          offset = first_arg.first
          limit  = first_arg.last - offset
          limit += 1 unless first_arg.exclude_end?
          return offset, limit
        end
      end

      raise ArgumentError, "arguments may be 1 or 2 Integers, or 1 Range object, was: #{args.inspect}"
    end

    # TODO: document
    # @api private
    def get_relative_position(offset, limit)
      new_offset = self.offset + offset

      if limit <= 0 || (self.limit && new_offset + limit > self.offset + self.limit)
        raise RangeError, "offset #{offset} and limit #{limit} are outside allowed range"
      end

      return new_offset, limit
    end

    ##
    # Return true if +other+'s is equivalent or equal to +self+'s
    #
    # @param [Query] other
    #   The Resource whose attributes are to be compared with +self+'s
    # @param [Symbol] operator
    #   The comparison operator to use to compare the attributes
    #
    # @return [TrueClass, FalseClass]
    #   The result of the comparison of +other+'s attributes with +self+'s
    #
    # @api private
    def cmp?(other, operator)
      # check the attributes that are most likely to differ first
      unless repository.send(operator, other.repository)
        return false
      end

      unless model.send(operator, other.model)
        return false
      end

      unless conditions.send(operator, other.conditions)
        return false
      end

      unless offset.send(operator, other.offset)
        return false
      end

      unless limit.send(operator, other.limit)
        return false
      end

      unless order.send(operator, other.order)
        return false
      end

      unless fields.sort_by { |property| property.hash }.send(operator, other.fields.sort_by { |property| property.hash })
        return false
      end

      unless links.send(operator, other.links)
        return false
      end

      unless reload?.send(operator, other.reload?)
        return false
      end

      unless unique?.send(operator, other.unique?)
        return false
      end

      unless add_reversed?.send(operator, other.add_reversed?)
        return false
      end

      true
    end

    # TODO: DRY this up with conditions
    # @api private
    def record_value(record, property)
      case record
        when Hash
          record.fetch(property, record[property.field])
        when Resource
          property.get!(record)
      end
    end

    # TODO: document
    # @api private
    def each_comparison
      operands = conditions.operands.dup

      while operand = operands.shift
        if operand.respond_to?(:operands)
          operands.concat(operand.operands)
        else
          yield operand
        end
      end
    end
  end # class Query
end # module DataMapper
