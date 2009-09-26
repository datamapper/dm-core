require 'data_objects'

module DataMapper
  module Adapters
    # DataObjectsAdapter is the base class for all adapers for relational
    # databases. If you want to add support for a new RDBMS, it makes
    # sense to make your adapter class inherit from this class.
    #
    # By inheriting from DataObjectsAdapter, you get a copy of all the
    # standard sub-modules (Quoting, Coersion and Queries) in your own Adapter.
    # You can extend and overwrite these copies without affecting the originals.
    class DataObjectsAdapter < AbstractAdapter
      extend Chainable

      # For each model instance in resources, issues an SQL INSERT
      # (or equivalent) statement to create a new record in the data store for
      # the instance
      #
      # Note that this method does not update identity map. A plugin needs to use
      # adapter directly, it is up to plugin developer to keep identity map
      # up to date.
      #
      # @param [Enumerable(Resource)] resources
      #   The list of resources (model instances) to create
      #
      # @return [Integer]
      #   The number of records that were actually saved into the database
      #
      # @api semipublic
      def create(resources)
        resources.each do |resource|
          model      = resource.model
          serial     = model.serial(name)
          attributes = resource.dirty_attributes

          properties  = []
          bind_values = []

          # make the order of the properties consistent
          model.properties(name).each do |property|
            next unless attributes.key?(property)

            bind_value = attributes[property]

            # skip insering NULL for columns that are serial or without a default
            next if bind_value.nil? && (property.serial? || !property.default?)

            # if serial is being set explicitly, do not set it again
            if property.equal?(serial)
              serial = nil
            end

            properties  << property
            bind_values << bind_value
          end

          statement = insert_statement(model, properties, serial)
          result    = execute(statement, *bind_values)

          if result.to_i == 1 && serial
            serial.set!(resource, result.insert_id)
          end
        end
      end

      # Constructs and executes SELECT query, then instantiates
      # one or many object from result set.
      #
      # @param [Query] query
      #   composition of the query to perform
      #
      # @return [Array]
      #   result set of the query
      #
      # @api semipublic
      def read(query)
        fields = query.fields
        types  = fields.map { |property| property.primitive }

        statement, bind_values = select_statement(query)

        records = []

        with_connection do |connection|
          command = connection.create_command(statement)
          command.set_types(types)

          reader = command.execute_reader(*bind_values)

          begin
            while reader.next!
              records << fields.zip(reader.values).to_hash
            end
          ensure
            reader.close
          end
        end

        records
      end

      # Constructs and executes UPDATE statement for given
      # attributes and a query
      #
      # @param [Hash(Property => Object)] attributes
      #   hash of attribute values to set, keyed by Property
      # @param [Collection] collection
      #   collection of records to be updated
      #
      # @return [Integer]
      #   the number of records updated
      #
      # @api semipublic
      def update(attributes, collection)
        query = collection.query

        # TODO: if the query contains any links, a limit or an offset
        # use a subselect to get the rows to be updated

        properties  = []
        bind_values = []

        # make the order of the properties consistent
        query.model.properties(name).each do |property|
          next unless attributes.key?(property)
          properties  << property
          bind_values << attributes[property]
        end

        statement, conditions_bind_values = update_statement(properties, query)

        bind_values.concat(conditions_bind_values)

        execute(statement, *bind_values).to_i
      end

      # Constructs and executes DELETE statement for given query
      #
      # @param [Collection] collection
      #   collection of records to be deleted
      #
      # @return [Integer]
      #   the number of records deleted
      #
      # @api semipublic
      def delete(collection)
        query = collection.query

        # TODO: if the query contains any links, a limit or an offset
        # use a subselect to get the rows to be deleted

        statement, bind_values = delete_statement(query)
        execute(statement, *bind_values).to_i
      end

      # Database-specific method
      # TODO: document
      # @api public
      def execute(statement, *bind_values)
        with_connection do |connection|
          command = connection.create_command(statement)
          command.execute_non_query(*bind_values)
        end
      end

      # TODO: document
      # @api public
      def query(statement, *bind_values)
        with_connection do |connection|
          reader = connection.create_command(statement).execute_reader(*bind_values)
          fields = reader.fields

          results = []

          begin
            if fields.size > 1
              fields = fields.map { |field| Extlib::Inflection.underscore(field).to_sym }
              struct = Struct.new(*fields)

              while reader.next!
                results << struct.new(*reader.values)
              end
            else
              while reader.next!
                results << reader.values.at(0)
              end
            end
          ensure
            reader.close
          end

          results
        end
      end

      protected

      # TODO: document
      # @api private
      def normalized_uri
        @normalized_uri ||=
          begin
            query = @options.except(:adapter, :user, :password, :host, :port, :path, :fragment, :scheme, :query, :username, :database)
            query = nil if query.empty?

            DataObjects::URI.new(
              @options[:adapter],
              @options[:user] || @options[:username],
              @options[:password],
              @options[:host],
              @options[:port],
              @options[:path] || @options[:database],
              query,
              @options[:fragment]
            ).freeze
          end
      end

      chainable do
        protected

        # Instantiates new connection object
        #
        # @api semipublic
        def open_connection
          # DataObjects::Connection.new(uri) will give you back the right
          # driver based on the DataObjects::URI#scheme
          connection = connection_stack.last || DataObjects::Connection.new(normalized_uri)
          connection_stack << connection
          connection
        end

        # Takes connection and closes it
        #
        # @api semipublic
        def close_connection(connection)
          connection_stack.pop
          connection.close if connection_stack.empty?
        end
      end

      private

      # TODO: document
      # @api public
      def initialize(name, uri_or_options)
        super

        # Default the driver-specific logger to DataMapper's logger
        if driver_module = DataObjects.const_get(normalized_uri.scheme.capitalize)
          driver_module.logger = DataMapper.logger if driver_module.respond_to?(:logger=)
        end
      end

      # TODO: document
      # @api private
      def connection_stack
        connection_stack_for = Thread.current[:dm_do_connection_stack] ||= {}
        connection_stack_for[self] ||= []
      end

      # TODO: document
      # @api private
      def with_connection
        begin
          yield connection = open_connection
        rescue Exception => exception
          DataMapper.logger.error(exception.to_s)
          raise exception
        ensure
          close_connection(connection) if connection
        end
      end

      # This module is just for organization. The methods are included into the
      # Adapter below.
      module SQL #:nodoc:
        IDENTIFIER_MAX_LENGTH = 128

        # TODO: document
        # @api semipublic
        def property_to_column_name(property, qualify)
          if qualify
            table_name = property.model.storage_name(name)
            "#{quote_name(table_name)}.#{quote_name(property.field)}"
          else
            quote_name(property.field)
          end
        end

        private

        # Adapters requiring a RETURNING syntax for INSERT statements
        # should overwrite this to return true.
        #
        # @api private
        def supports_returning?
          false
        end

        # Adapters that do not support the DEFAULT VALUES syntax for
        # INSERT statements should overwrite this to return false.
        #
        # @api private
        def supports_default_values?
          true
        end

        # Constructs SELECT statement for given query,
        #
        # @return [String] SELECT statement as a string
        #
        # @api private
        def select_statement(query)
          qualify  = query.links.any?
          fields   = query.fields
          order_by = query.order
          group_by = if qualify || query.unique?
            fields.select { |property| property.kind_of?(Property) }
          end

          conditions_statement, bind_values = conditions_statement(query.conditions, qualify)

          statement = "SELECT #{columns_statement(fields, qualify)}"
          statement << " FROM #{quote_name(query.model.storage_name(name))}"
          statement << join_statement(query, qualify)                      if qualify
          statement << " WHERE #{conditions_statement}"                    unless conditions_statement.blank?
          statement << " GROUP BY #{columns_statement(group_by, qualify)}" if group_by && group_by.any?
          statement << " ORDER BY #{order_statement(order_by, qualify)}"   if order_by && order_by.any?

          add_limit_offset!(statement, query.limit, query.offset, bind_values)

          return statement, bind_values
        end

        # default construction of LIMIT and OFFSET
        # overriden in Oracle adapter
        def add_limit_offset!(statement, limit, offset, bind_values)
          if limit
            statement   << ' LIMIT ?'
            bind_values << limit
          end

          if limit && offset > 0
            statement   << ' OFFSET ?'
            bind_values << offset
          end
        end

        # Constructs INSERT statement for given query,
        #
        # @return [String] INSERT statement as a string
        #
        # @api private
        def insert_statement(model, properties, serial)
          statement = "INSERT INTO #{quote_name(model.storage_name(name))} "

          if supports_default_values? && properties.empty?
            statement << default_values_clause
          else
            statement << <<-SQL.compress_lines
              (#{properties.map { |property| quote_name(property.field) }.join(', ')})
              VALUES
              (#{(['?'] * properties.size).join(', ')})
            SQL
          end

          if supports_returning? && serial
            statement << returning_clause(serial)
          end

          statement
        end

        # by default PostgreSQL syntax
        # overrided in Oracle adapter
        def default_values_clause
          'DEFAULT VALUES'
        end

        # by default PostgreSQL syntax
        # overrided in Oracle adapter
        def returning_clause(serial)
          " RETURNING #{quote_name(serial.field)}"
        end

        # Constructs UPDATE statement for given query,
        #
        # @return [String] UPDATE statement as a string
        #
        # @api private
        def update_statement(properties, query)
          conditions_statement, bind_values = conditions_statement(query.conditions)

          statement = "UPDATE #{quote_name(query.model.storage_name(name))}"
          statement << " SET #{properties.map { |property| "#{quote_name(property.field)} = ?" }.join(', ')}"
          statement << " WHERE #{conditions_statement}" unless conditions_statement.blank?

          return statement, bind_values
        end

        # Constructs DELETE statement for given query,
        #
        # @return [String] DELETE statement as a string
        #
        # @api private
        def delete_statement(query)
          conditions_statement, bind_values = conditions_statement(query.conditions)

          statement = "DELETE FROM #{quote_name(query.model.storage_name(name))}"
          statement << " WHERE #{conditions_statement}" unless conditions_statement.blank?

          return statement, bind_values
        end

        # Constructs comma separated list of fields
        #
        # @return [String]
        #   list of fields as a string
        #
        # @api private
        def columns_statement(properties, qualify)
          properties.map { |property| property_to_column_name(property, qualify) }.join(', ')
        end

        # Constructs joins clause
        #
        # @return [String]
        #   joins clause
        #
        # @api private
        def join_statement(query, qualify)
          statement = ''

          query.links.reverse_each do |relationship|
            statement << " INNER JOIN #{quote_name(relationship.source_model.storage_name(name))} ON "
            statement << relationship.target_key.zip(relationship.source_key).map do |target_property, source_property|
              "#{property_to_column_name(target_property, qualify)} = #{property_to_column_name(source_property, qualify)}"
            end.join(' AND ')
          end

          statement
        end

        # Constructs where clause
        #
        # @return [String]
        #   where clause
        #
        # @api private
        def conditions_statement(conditions, qualify = false)
          case conditions
            when Query::Conditions::NotOperation
              negate_operation(conditions, qualify)

            when Query::Conditions::AbstractOperation
              # TODO: remove this once conditions can be compressed
              if conditions.operands.size == 1
                # factor out operations with a single operand
                conditions_statement(conditions.operands.first, qualify)
              else
                operation_statement(conditions, qualify)
              end

            when Query::Conditions::AbstractComparison
              comparison_statement(conditions, qualify)

            when Array
              statement, bind_values = conditions  # handle raw conditions
              [ "(#{statement})", bind_values ]
          end
        end

        # Constructs order clause
        #
        # @return [String]
        #   order clause
        #
        # @api private
        def order_statement(order, qualify)
          statements = order.map do |direction|
            statement = property_to_column_name(direction.target, qualify)
            statement << ' DESC' if direction.operator == :desc
            statement
          end

          statements.join(', ')
        end

        # TODO: document
        # @api private
        def negate_operation(operation, qualify)
          @negated = !@negated
          begin
            conditions_statement(operation.operands.first, qualify)
          ensure
            @negated = !@negated
          end
        end

        # TODO: document
        # @api private
        def operation_statement(operation, qualify)
          statements  = []
          bind_values = []

          operation.each do |operand|
            statement, values = conditions_statement(operand, qualify)

            if operand.respond_to?(:operands) && operand.operands.size > 1
              statement = "(#{statement})"
            end

            statements << statement
            bind_values.concat(values)
          end

          join_with = operation.kind_of?(@negated ? Query::Conditions::OrOperation : Query::Conditions::AndOperation) ? 'AND' : 'OR'
          statement = statements.join(" #{join_with} ")

          return statement, bind_values
        end

        # Constructs comparison clause
        #
        # @return [String]
        #   comparison clause
        #
        # @api private
        def comparison_statement(comparison, qualify)
          value = comparison.value

          # TODO: move exclusive Range handling into another method, and
          # update conditions_statement to use it

          # break exclusive Range queries up into two comparisons ANDed together
          if value.kind_of?(Range) && value.exclude_end?
            operation = Query::Conditions::Operation.new(:and,
              Query::Conditions::Comparison.new(:gte, comparison.subject, value.first),
              Query::Conditions::Comparison.new(:lt,  comparison.subject, value.last)
            )

            statement, bind_values = conditions_statement(operation, qualify)

            return "(#{statement})", bind_values
          elsif comparison.relationship?
            return conditions_statement(comparison.foreign_key_mapping, qualify)
          end

          operator = case comparison
            when Query::Conditions::EqualToComparison              then @negated ? inequality_operator(comparison.subject, value) : equality_operator(comparison.subject, value)
            when Query::Conditions::InclusionComparison            then @negated ? exclude_operator(comparison.subject, value)    : include_operator(comparison.subject, value)
            when Query::Conditions::RegexpComparison               then @negated ? not_regexp_operator(value) : regexp_operator(value)
            when Query::Conditions::LikeComparison                 then @negated ? unlike_operator(value)     : like_operator(value)
            when Query::Conditions::GreaterThanComparison          then @negated ? '<='                       : '>'
            when Query::Conditions::LessThanComparison             then @negated ? '>='                       : '<'
            when Query::Conditions::GreaterThanOrEqualToComparison then @negated ? '<'                        : '>='
            when Query::Conditions::LessThanOrEqualToComparison    then @negated ? '>'                        : '<='
          end

          # if operator return value contains ? then it means that it is function call
          # and it contains placeholder (%s) for property name as well (used in Oracle adapter for regexp operator)
          if operator.include?('?')
            return operator % property_to_column_name(comparison.subject, qualify), [ value ]
          else
            return "#{property_to_column_name(comparison.subject, qualify)} #{operator} #{value.nil? ? 'NULL' : '?'}", [ value ].compact
          end
        end

        # TODO: document
        # @api private
        def equality_operator(property, operand)
          operand.nil? ? 'IS' : '='
        end

        # TODO: document
        # @api private
        def inequality_operator(property, operand)
          operand.nil? ? 'IS NOT' : '<>'
        end

        # TODO: document
        # @api private
        def include_operator(property, operand)
          case operand
            when Array then 'IN'
            when Range then 'BETWEEN'
          end
        end

        # TODO: document
        # @api private
        def exclude_operator(property, operand)
          "NOT #{include_operator(property, operand)}"
        end

        # TODO: document
        # @api private
        def regexp_operator(operand)
          '~'
        end

        # TODO: document
        # @api private
        def not_regexp_operator(operand)
          '!~'
        end

        # TODO: document
        # @api private
        def like_operator(operand)
          'LIKE'
        end

        # TODO: document
        # @api private
        def unlike_operator(operand)
          'NOT LIKE'
        end

        # TODO: document
        # @api private
        def quote_name(name)
          "\"#{name[0, self.class::IDENTIFIER_MAX_LENGTH].gsub('"', '""')}\""
        end
      end #module SQL

      include SQL
    end # class DataObjectsAdapter

    const_added(:DataObjectsAdapter)
  end # module Adapters
end # module DataMapper
