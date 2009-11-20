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
    extend Equalizer

    OPTIONS = [ :fields, :links, :conditions, :offset, :limit, :order, :unique, :add_reversed, :reload ].to_set.freeze

    equalize :repository, :model, :sorted_fields, :links, :conditions, :order, :offset, :limit, :reload?, :unique?, :add_reversed?

    # Extract conditions to match a Resource or Collection
    #
    # @param [Array, Collection, Resource] source
    #   the source to extract the values from
    # @param [ProperySet] source_key
    #   the key to extract the value from the resource
    # @param [ProperySet] target_key
    #   the key to match the resource with
    #
    # @return [AbstractComparison, AbstractOperation]
    #   the conditions to match the resources with
    #
    # @api private
    def self.target_conditions(source, source_key, target_key)
      target_key_size = target_key.size
      source_values   = []

      if source.nil?
        source_values << [ nil ] * target_key_size
      else
        Array(source).each do |resource|
          next unless source_key.loaded?(resource)
          source_value = source_key.get!(resource)
          next unless target_key.valid?(source_value)
          source_values << source_value
        end
      end

      source_values.uniq!

      if target_key_size == 1
        target_key = target_key.first
        source_values.flatten!

        if source_values.size == 1
          Conditions::EqualToComparison.new(target_key, source_values.first)
        else
          Conditions::InclusionComparison.new(target_key, source_values)
        end
      else
        or_operation = Conditions::OrOperation.new

        source_values.each do |source_value|
          and_operation = Conditions::AndOperation.new

          target_key.zip(source_value) do |property, value|
            and_operation << Conditions::EqualToComparison.new(property, value)
          end

          or_operation << and_operation
        end

        or_operation
      end
    end

    # @param [Repository] repository
    #   the default repository to scope the query within
    # @param [Model] model
    #   the default model for the query
    # @param [#query, Enumerable] source
    #   the source to generate the query with
    #
    # @return [Query]
    #   the query to match the resources with
    #
    # @api private
    def self.target_query(repository, model, source)
      if source.respond_to?(:query)
        source.query
      elsif source.kind_of?(Enumerable)
        key        = model.key(repository.name)
        conditions = Query.target_conditions(source, key, key)
        Query.new(repository, model, :conditions => conditions)
      else
        raise ArgumentError, "+source+ must respond to #query or be an Enumerable, but was #{source.class}"
      end
    end

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

    # Returns model (class) that is used
    # to instantiate objects from query result
    # returned by adapter
    #
    # @return [Model]
    #   the Model to retrieve results from
    #
    # @api semipublic
    attr_reader :model

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

    # Returns the links (associations) query fetches
    #
    # @return [Array<DataMapper::Associations::Relationship>]
    #   the relationships that will be used to scope the results
    #
    # @api private
    attr_reader :links

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

    # Returns the limit query uses
    #
    # Set in cases like the following:
    #
    # @example
    #
    #   Document.all(:limit => 10)
    #
    # @return [Integer, nil]
    #   the maximum number of results
    #
    # @api semipublic
    attr_reader :limit

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

    # Returns the original options
    #
    # @return [Hash]
    #   the original options
    #
    # @api private
    attr_reader :options

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
    # @return [Boolean]
    #   true if the results should be reversed, false if not
    #
    # @api private
    def add_reversed?
      @add_reversed
    end

    # Indicates if the Query results should replace the results in the Identity Map
    #
    #   TODO: needs example
    #
    # @return [Boolean]
    #   true if the results should be reloaded, false if not
    #
    # @api semipublic
    def reload?
      @reload
    end

    # Indicates if the Query results should be unique
    #
    #   TODO: needs example
    #
    # @return [Boolean]
    #   true if the results should be unique, false if not
    #
    # @api semipublic
    def unique?
      @unique
    end

    # Indicates if the Query has raw conditions
    #
    # @return [Boolean]
    #   true if the query has raw conditions, false if not
    #
    # @api semipublic
    def raw?
      @raw
    end

    # Indicates if the Query is valid
    #
    # @return [Boolean]
    #   true if the query is valid
    #
    # @api semipublic
    def valid?
      conditions.valid?
    end

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

      other_options = if kind_of?(other.class)
        return self if self.eql?(other)
        assert_valid_other(other)
        other.options
      else
        return self if other.empty?
        other
      end

      @options = @options.merge(other_options).freeze
      assert_valid_options(@options)

      normalize = other_options.only(*OPTIONS - [ :conditions ]).map do |attribute, value|
        instance_variable_set("@#{attribute}", value.try_dup)
        attribute
      end

      merge_conditions([ other_options.except(*OPTIONS), other_options[:conditions] ])
      normalize_options(normalize | [ :links, :unique ])

      self
    end

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

      offset = nil
      limit  = self.limit

      if options.key?(:offset) && (options.key?(:limit) || limit)
        options = options.dup
        offset  = options.delete(:offset)
        limit   = options.delete(:limit) || limit - offset
      end

      query = merge(options)
      query = query.slice!(offset, limit) if offset
      query
    end

    # Return the union with another query
    #
    # @param [Query] other
    #   the other query
    #
    # @return [Query]
    #   the union of the query and other
    #
    # @api semipublic
    def union(other)
      return dup if self == other
      set_operation(:union, other)
    end

    alias | union
    alias + union

    # Return the intersection with another query
    #
    # @param [Query] other
    #   the other query
    #
    # @return [Query]
    #   the intersection of the query and other
    #
    # @api semipublic
    def intersection(other)
      return dup if self == other
      set_operation(:intersection, other)
    end

    alias & intersection

    # Return the difference with another query
    #
    # @param [Query] other
    #   the other query
    #
    # @return [Query]
    #   the difference of the query and other
    #
    # @api semipublic
    def difference(other)
      set_operation(:difference, other)
    end

    alias - difference

    # Clear conditions
    #
    # @return [self]
    #
    # @api semipublic
    def clear
      @conditions = Conditions::Operation.new(:null)
      self
    end

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
      conditions = self.conditions
      return records if conditions.nil?
      records.select { |record| conditions.matches?(record) }
    end

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
      offset = self.offset
      limit  = self.limit
      size   = records.size

      if offset > size - 1
        []
      elsif (limit && limit != size) || offset > 0
        records[offset, limit || size] || []
      else
        records.dup
      end
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

    # Get the properties used in the conditions
    #
    # @return [Set<Property>]
    #  Set of properties used in the conditions
    #
    # @api private
    def condition_properties
      properties = Set.new

      each_comparison do |comparison|
        next unless comparison.respond_to?(:subject)
        subject = comparison.subject
        properties << subject if subject.kind_of?(Property)
      end

      properties
    end

    # Return a list of fields in predictable order
    #
    # @return [Array<Property>]
    #   list of fields sorted in deterministic order
    #
    # @api private
    def sorted_fields
      fields.sort_by { |property| property.hash }
    end

    # Transform Query into subquery conditions
    #
    # @return [AndOperation]
    #   a subquery for the Query
    #
    # @api private
    def to_subquery
      collection = model.all(merge(:fields => model_key))
      Conditions::Operation.new(:and, Conditions::Comparison.new(:in, self_relationship, collection))
    end

    # Hash representation of a Query
    #
    # @return [Hash]
    #   Hash representation of a Query
    #
    # @api private
    def to_hash
      {
        :repository   => repository.name,
        :model        => model.name,
        :fields       => fields,
        :links        => links,
        :conditions   => conditions,
        :offset       => offset,
        :limit        => limit,
        :order        => order,
        :unique       => unique?,
        :add_reversed => add_reversed?,
        :reload       => reload?,
      }
    end

    # Extract options from a Query
    #
    # @param [Query] query
    #   the query to extract options from
    #
    # @return [Hash]
    #   the options to use to initialize the new query
    #
    # @api private
    def to_relative_hash
      to_hash.only(:fields, :order, :unique, :add_reversed, :reload)
    end

    private

    # Initializes a Query instance
    #
    # @example
    #
    #  JournalIssue.all(:repository => :medline, :created_on.gte => Date.today - 7)
    #
    # initialized a query with repository defined with name :medline,
    # model JournalIssue and options { :created_on.gte => Date.today - 7 }
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
      @links        = @options.key?(:links) ? @options[:links].dup : []
      @conditions   = Conditions::Operation.new(:null)
      @offset       = @options.fetch :offset,       0
      @limit        = @options.fetch :limit,        nil
      @order        = @options.fetch :order,        @model.default_order(repository_name)
      @unique       = @options.fetch :unique,       false
      @add_reversed = @options.fetch :add_reversed, false
      @reload       = @options.fetch :reload,       false
      @raw          = false

      merge_conditions([ @options.except(*OPTIONS), @options[:conditions] ])
      normalize_options
    end

    # Copying contructor, called for Query#dup
    #
    # @api semipublic
    def initialize_copy(*)
      @fields     = @fields.dup
      @links      = @links.dup
      @conditions = @conditions.dup
      @order      = @order.try_dup
    end

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

      model = self.model

      fields.each do |field|
        inspect = field.inspect

        case field
          when Symbol, String
            unless @properties.named?(field)
              raise ArgumentError, "+options[:fields]+ entry #{inspect} does not map to a property in #{model}"
            end

          when Property
            unless @properties.include?(field)
              raise ArgumentError, "+options[:field]+ entry #{field.name.inspect} does not map to a property in #{model}"
            end

          else
            raise ArgumentError, "+options[:fields]+ entry #{inspect} of an unsupported object #{field.class}"
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
        inspect = link.inspect

        case link
          when Symbol, String
            unless @relationships.key?(link.to_sym)
              raise ArgumentError, "+options[:links]+ entry #{inspect} does not map to a relationship in #{model}"
            end

          when Associations::Relationship
            # TODO: figure out how to validate links from other models
            #unless @relationships.value?(link)
            #  raise ArgumentError, "+options[:links]+ entry #{link.name.inspect} does not map to a relationship in #{model}"
            #end

          else
            raise ArgumentError, "+options[:links]+ entry #{inspect} of an unsupported object #{link.class}"
        end
      end
    end

    # Verifies that value of :conditions option
    # refers to existing properties
    #
    # @api private
    def assert_valid_conditions(conditions)
      assert_kind_of 'options[:conditions]', conditions, Conditions::AbstractOperation, Conditions::AbstractComparison, Hash, Array

      case conditions
        when Hash
          conditions.each do |subject, bind_value|
            inspect = subject.inspect

            case subject
              when Symbol, String
                unless subject.to_s.include?('.') || @properties.named?(subject) || @relationships.key?(subject)
                  raise ArgumentError, "condition #{inspect} does not map to a property or relationship in #{model}"
                end

              when Operator
                operator = subject.operator

                unless (Conditions::Comparison.slugs | [ :not ]).include?(operator)
                  raise ArgumentError, "condition #{inspect} used an invalid operator #{operator}"
                end

                assert_valid_conditions(subject.target => bind_value)

              when Path
                assert_valid_links(subject.relationships)

              when Associations::Relationship, Property
                # TODO: validate that it belongs to the current model, or to any
                # model in the links
                #unless @properties.include?(subject)
                #  raise ArgumentError, "condition #{subject.name.inspect} does not map to a property in #{model}"
                #end

              else
                raise ArgumentError, "condition #{inspect} of an unsupported object #{subject.class}"
            end
          end

        when Array
          if conditions.empty?
            raise ArgumentError, '+options[:conditions]+ should not be empty'
          end

          first_condition = conditions.first

          unless first_condition.kind_of?(String) && !first_condition.blank?
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

    # Verifies the limit is equal to or greater than 0
    #
    # @raise [ArgumentError]
    #   raised if the limit is not an Integer or less than 0
    #
    # @api private
    def assert_valid_limit(limit)
      assert_kind_of 'options[:limit]', limit, Integer

      unless limit >= 0
        raise ArgumentError, "+options[:limit]+ must be greater than or equal to 0, but was #{limit.inspect}"
      end
    end

    # Verifies that :order option uses proper operator and refers
    # to existing property
    #
    # @api private
    def assert_valid_order(order, fields)
      return if order.nil?

      order = Array(order)
      if order.empty? && fields && fields.any? { |property| !property.kind_of?(Operator) }
        raise ArgumentError, '+options[:order]+ should not be empty if +options[:fields] contains a non-operator'
      end

      model = self.model

      order.each do |order_entry|
        inspect = order_entry.inspect

        case order_entry
          when Symbol, String
            unless @properties.named?(order_entry)
              raise ArgumentError, "+options[:order]+ entry #{inspect} does not map to a property in #{model}"
            end

          when Property
            unless @properties.include?(order_entry)
              raise ArgumentError, "+options[:order]+ entry #{order_entry.name.inspect} does not map to a property in #{model}"
            end

          when Operator, Direction
            operator = order_entry.operator

            unless operator == :asc || operator == :desc
              raise ArgumentError, "+options[:order]+ entry #{inspect} used an invalid operator #{operator}"
            end

            assert_valid_order([ order_entry.target ], fields)

          else
            raise ArgumentError, "+options[:order]+ entry #{inspect} of an unsupported object #{order_entry.class}"
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
      other_repository = other.repository
      repository       = self.repository
      other_class      = other.class

      unless other_repository == repository
        raise ArgumentError, "+other+ #{other_class} must be for the #{repository.name} repository, not #{other_repository.name}"
      end

      other_model = other.model
      model       = self.model

      unless other_model >= model
        raise ArgumentError, "+other+ #{other_class} must be for the #{model.name} model, not #{other_model.name}"
      end
    end

    # Handle all the conditions options provided
    #
    # @param [Array<Conditions::AbstractOperation, Conditions::AbstractComparison, Hash, Array>]
    #   a list of conditions
    #
    # @return [undefined]
    #
    # @api private
    def merge_conditions(conditions)
      @conditions = Conditions::Operation.new(:and) << @conditions unless @conditions.nil?

      conditions.compact!
      conditions.each do |condition|
        case condition
          when Conditions::AbstractOperation, Conditions::AbstractComparison
            add_condition(condition)

          when Hash
            condition.each { |kv| append_condition(*kv) }

          when Array
            statement, *bind_values = *condition
            raw_condition = [ statement ]
            raw_condition << bind_values if bind_values.size > 0
            add_condition(raw_condition)
            @raw = true
        end
      end
    end

    # Normalize options
    #
    # @param [Array<Symbol>] options
    #   the options to normalize
    #
    # @return [undefined]
    #
    # @api private
    def normalize_options(options = OPTIONS)
      (options & [ :order, :fields, :links, :unique ]).each do |option|
        send("normalize_#{option}")
      end
    end

    # Normalize order elements to Query::Direction instances
    #
    # @api private
    def normalize_order
      return if @order.nil?

      # TODO: should Query::Path objects be permitted?  If so, then it
      # should probably be normalized to a Direction object
      @order = Array(@order)
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

    # Normalize fields to Property instances
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

    # Normalize links to Query::Path
    #
    # Normalization means links given as symbols are replaced with
    # relationships they refer to, intermediate links are "followed"
    # and duplicates are removed
    #
    # @api private
    def normalize_links
      stack = @links.dup

      @links.clear

      while link = stack.pop
        relationship = case link
          when Symbol, String             then @relationships[link]
          when Associations::Relationship then link
        end

        if relationship.respond_to?(:links)
          stack.concat(relationship.links)
        elsif !@links.include?(relationship)
          repository_name = relationship.relative_target_repository_name
          model           = relationship.target_model

          # TODO: see if this can handle extracting the :order option and sort the
          # resulting collection using the order specified by through relationships

          model.current_scope.merge(relationship.query).each do |subject, value|
            # TODO: figure out how to merge Query options from links
            if OPTIONS.include?(subject)
              next  # skip for now
            end

            # set @repository when appending conditions
            original, @repository = @repository, DataMapper.repository(repository_name)

            begin
              append_condition(subject, value, model)
            ensure
              @repository = original
            end
          end

          @links << relationship
        end
      end

      @links.reverse!
    end

    # Normalize the unique attribute
    #
    # If any links are present, and the unique attribute was not
    # explicitly specified, then make sure the query is marked as unique
    #
    # @api private
    def normalize_unique
      @unique = @links.any? unless @options.key?(:unique)
    end

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
    def append_condition(subject, bind_value, model = self.model, operator = :eql)
      case subject
        when Property, Associations::Relationship then append_property_condition(subject, bind_value, operator)
        when Symbol                               then append_symbol_condition(subject, bind_value, model, operator)
        when String                               then append_string_condition(subject, bind_value, model, operator)
        when Operator                             then append_operator_conditions(subject, bind_value, model)
        when Path                                 then append_path(subject, bind_value, model, operator)
        else
          raise ArgumentError, "#{subject} is an invalid instance: #{subject.class}"
      end
    end

    # @api private
    def append_property_condition(subject, bind_value, operator)
      negated = operator == :not

      if operator == :eql || negated
        # transform :relationship => nil into :relationship.not => association
        if subject.respond_to?(:collection_for) && bind_value.nil?
          negated    = !negated
          bind_value = collection_for_nil(subject)
        end

        operator = equality_operator_for_type(bind_value)
      end

      condition = Conditions::Comparison.new(operator, subject, bind_value)

      if negated
        condition = Conditions::Operation.new(:not, condition)
      end

      add_condition(condition)
    end

    if RUBY_VERSION >= '1.9'
      def equality_operator_for_type(bind_value)
        case bind_value
          when Enumerable then :in
          when Regexp     then :regexp
          else                 :eql
        end
      end
    else
      def equality_operator_for_type(bind_value)
        case bind_value
          when String     then :eql
          when Enumerable then :in
          when Regexp     then :regexp
          else                 :eql
        end
      end
    end

    # @api private
    def append_symbol_condition(symbol, bind_value, model, operator)
      append_condition(symbol.to_s, bind_value, model, operator)
    end

    # @api private
    def append_string_condition(string, bind_value, model, operator)
      if string.include?('.')
        query_path = model

        target_components = string.split('.')
        last_component    = target_components.last
        operator          = target_components.pop.to_sym if DataMapper::Query::Conditions::Comparison.slugs.any? { |slug| slug.to_s == last_component }

        target_components.each { |method| query_path = query_path.send(method) }

        append_condition(query_path, bind_value, model, operator)
      else
        repository_name = repository.name
        subject         = model.properties(repository_name)[string] ||
                          model.relationships(repository_name)[string]

        append_condition(subject, bind_value, model, operator)
      end
    end

    # @api private
    def append_operator_conditions(operator, bind_value, model)
      append_condition(operator.target, bind_value, model, operator.operator)
    end

    # @api private
    def append_path(path, bind_value, model, operator)
      path.relationships.each do |relationship|
        inverse = relationship.inverse
        @links.unshift(inverse) unless @links.include?(inverse)
      end

      append_condition(path.property, bind_value, path.model, operator)
    end

    # Add a condition to the Query
    #
    # @param [AbstractOperation, AbstractComparison]
    #   the condition to add to the Query
    #
    # @return [undefined]
    #
    # @api private
    def add_condition(condition)
      @conditions = Conditions::Operation.new(:and) if @conditions.nil?
      @conditions << condition
    end

    # Extract arguments for #slice and #slice! then return offset and limit
    #
    # @param [Integer, Array(Integer), Range] *args the offset,
    #   offset and limit, or range indicating first and last position
    #
    # @return [Integer] the offset
    # @return [Integer, nil] the limit, if any
    #
    # @api private
    def extract_slice_arguments(*args)
      offset, limit = case args.size
        when 2 then extract_offset_limit_from_two_arguments(*args)
        when 1 then extract_offset_limit_from_one_argument(*args)
      end

      return offset, limit if offset && limit

      raise ArgumentError, "arguments may be 1 or 2 Integers, or 1 Range object, was: #{args.inspect}"
    end

    # @api private
    def extract_offset_limit_from_two_arguments(*args)
      args if args.all? { |arg| arg.kind_of?(Integer) }
    end

    # @api private
    def extract_offset_limit_from_one_argument(arg)
      case arg
        when Integer then extract_offset_limit_from_integer(arg)
        when Range   then extract_offset_limit_from_range(arg)
      end
    end

    # @api private
    def extract_offset_limit_from_integer(integer)
      [ integer, 1 ]
    end

    # @api private
    def extract_offset_limit_from_range(range)
      offset = range.first
      limit  = range.last - offset
      limit  = limit.succ unless range.exclude_end?
      return offset, limit
    end

    # @api private
    def get_relative_position(offset, limit)
      self_offset = self.offset
      self_limit  = self.limit
      new_offset  = self_offset + offset

      if limit <= 0 || (self_limit && new_offset + limit > self_offset + self_limit)
        raise RangeError, "offset #{offset} and limit #{limit} are outside allowed range"
      end

      return new_offset, limit
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

    # @api private
    def collection_for_nil(relationship)
      query = relationship.query.dup

      relationship.target_key.each do |target_key|
        query[target_key.name.not] = nil if target_key.allow_nil?
      end

      relationship.target_model.all(query)
    end

    # @api private
    def each_comparison
      operands = conditions.operands.to_a

      while operand = operands.shift
        if operand.respond_to?(:operands)
          operands.unshift(*operand.operands)
        else
          yield operand
        end
      end
    end

    # Apply a set operation on self and another query
    #
    # @param [Symbol] operation
    #   the set operation to apply
    # @param [Query] other
    #   the other query to apply the set operation on
    #
    # @return [Query]
    #   the query that was created for the set operation
    #
    # @api private
    def set_operation(operation, other)
      assert_valid_other(other)
      query = self.class.new(@repository, @model, other.to_relative_hash)
      query.instance_variable_set(:@conditions, other_conditions(other, operation))
      query
    end

    # Return the union with another query's conditions
    #
    # @param [Query] other
    #   the query conditions to union with
    #
    # @return [OrOperation]
    #   the union of the query conditions and other conditions
    #
    # @api private
    def other_conditions(other, operation)
      query_conditions(self).send(operation, query_conditions(other))
    end

    # Extract conditions from a Query
    #
    # @param [Query] query
    #   the query with conditions
    #
    # @return [AbstractOperation]
    #   the operation
    #
    # @api private
    def query_conditions(query)
      if query.limit || query.links.any?
        query.to_subquery
      else
        query.conditions
      end
    end

    # Return a self referrential relationship
    #
    # @return [Associations::OneToMany::Relationship]
    #   the 1:m association to the same model
    #
    # @api private
    def self_relationship
      @self_relationship ||=
        begin
          model = self.model
          Associations::OneToMany::Relationship.new(
            :self,
            model,
            model,
            self_relationship_options
            )
        end
    end

    # Return options for the self referrential relationship
    #
    # @return [Hash]
    #   the options to use with the self referrential relationship
    #
    # @api private
    def self_relationship_options
      keys       = model_key.map { |property| property.name }
      repository = self.repository
      {
        :child_key              => keys,
        :parent_key             => keys,
        :child_repository_name  => repository,
        :parent_repository_name => repository,
      }
    end

    # Return the model key
    #
    # @return [PropertySet]
    #   the model key
    #
    # @api private
    def model_key
      @properties.key
    end
  end # class Query
end # module DataMapper
