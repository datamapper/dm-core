gem 'data_objects', '~>0.9.12'
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

      ##
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
          model          = resource.model
          identity_field = model.identity_field
          attributes     = resource.dirty_attributes

          properties  = []
          bind_values = []

          # make the order of the properties consistent
          model.properties(name).each do |property|
            next unless attributes.key?(property)

            bind_value = attributes[property]

            next if property.eql?(identity_field) && bind_value.nil?

            properties  << property
            bind_values << bind_value
          end

          statement = insert_statement(model, properties, identity_field)
          result    = execute(statement, *bind_values)

          if result.to_i == 1
            if identity_field
              identity_field.set!(resource, result.insert_id)
            end
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
        types  = fields.map { |p| p.primitive }

        resources = []

        with_connection do |connection|
          statement, bind_values = select_statement(query)

          command = connection.create_command(statement)
          command.set_types(types)

          reader = command.execute_reader(*bind_values)

          begin
            while(reader.next!)
              resources << fields.zip(reader.values).to_hash
            end
          ensure
            reader.close
          end
        end

        resources
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
          begin
            reader = connection.create_command(statement).execute_reader(*bind_values)

            results = []

            if (fields = reader.fields).size > 1
              fields = fields.map { |f| Extlib::Inflection.underscore(f).to_sym }
              struct = Struct.new(*fields)

              while(reader.next!) do
                results << struct.new(*reader.values)
              end
            else
              while(reader.next!) do
                results << reader.values.at(0)
              end
            end

            results
          ensure
            reader.close if reader
          end
        end
      end

      protected

      # TODO: document
      # @api private
      def normalized_uri
        @normalized_uri ||=
          begin
            query = @options.except(:adapter, :user, :password, :host, :port, :path, :fragment, :scheme, :query)
            query = nil if query.empty?

            DataObjects::URI.new(
              @options[:adapter],
              @options[:user],
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
        def create_connection
          # DataObjects::Connection.new(uri) will give you back the right
          # driver based on the DataObjects::URI#scheme
          DataObjects::Connection.new(normalized_uri)
        end

        # Takes connection and closes it
        #
        # @api semipublic
        def close_connection(connection)
          connection.close
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
      def with_connection
        begin
          connection = create_connection
          return yield(connection)
        rescue => e
          DataMapper.logger.error(e.to_s)
          raise e
        ensure
          close_connection(connection) if connection
        end
      end

      # This module is just for organization. The methods are included into the
      # Adapter below.
      module SQL #:nodoc:

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
          model      = query.model
          fields     = query.fields
          conditions = query.conditions
          limit      = query.limit
          offset     = query.offset
          order      = query.order
          group_by   = nil

          # FIXME: using a boolean for qualify does not work in some cases,
          # such as when you have a self-referrential many to many association.
          # if you don't qualfiy the columns with a unique alias, then the
          # SQL query will fail.  This may mean though, that it might not
          # be enough to pass in a Property, but we may need to know the
          # table and the alias we should use for the column.

          qualify = query.links.any?

          if qualify || query.unique?
            group_by = fields.select { |p| p.kind_of?(Property) }
          end

          unless (limit && limit > 1) || offset > 0 || qualify
            operands = conditions.operands

            # TODO: move this method to Query, so that it walks the conditions
            # and finds an OR operator

            # if a unique property is used, and there is no OR operator, then an ORDER
            # and LIMIT are unecessary because it should only return a single row
            if conditions.kind_of?(Conditions::AndOperation) &&
               operands.any? { |o| o.kind_of?(Conditions::EqualToComparison) && o.property.unique? } &&
               !operands.any? { |o| o.kind_of?(Conditions::OrOperation) }
              order = nil
              limit = nil
            end
          end

          conditions_statement, bind_values = conditions_statement(conditions, qualify)

          statement = "SELECT #{columns_statement(fields, qualify)}"
          statement << " FROM #{quote_name(model.storage_name(name))}"
          statement << join_statement(query.links, qualify)                if qualify
          statement << " WHERE #{conditions_statement}"                    unless conditions_statement.blank?
          statement << " GROUP BY #{columns_statement(group_by, qualify)}" unless group_by.blank?
          statement << " ORDER BY #{order_statement(order, qualify)}"      unless order.blank?

          if limit
            statement   << ' LIMIT ?'
            bind_values << limit
          end

          if limit && offset > 0
            statement   << ' OFFSET ?'
            bind_values << offset
          end

          return statement, bind_values
        end

        # Constructs INSERT statement for given query,
        #
        # @return [String] INSERT statement as a string
        #
        # @api private
        def insert_statement(model, properties, identity_field)
          statement = "INSERT INTO #{quote_name(model.storage_name(name))} "

          if supports_default_values? && properties.empty?
            statement << 'DEFAULT VALUES'
          else
            statement << <<-SQL.compress_lines
              (#{properties.map { |p| quote_name(p.field) }.join(', ')})
              VALUES
              (#{(['?'] * properties.size).join(', ')})
            SQL
          end

          if supports_returning? && identity_field
            statement << " RETURNING #{quote_name(identity_field.field)}"
          end

          statement
        end

        # Constructs UPDATE statement for given query,
        #
        # @return [String] UPDATE statement as a string
        #
        # @api private
        def update_statement(properties, query)
          conditions_statement, bind_values = conditions_statement(query.conditions)

          statement = "UPDATE #{quote_name(query.model.storage_name(name))}"
          statement << " SET #{properties.map { |p| "#{quote_name(p.field)} = ?" }.join(', ')}"
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
        # @return [String] list of fields as a string
        def columns_statement(properties, qualify)
          properties.map { |p| property_to_column_name(p, qualify) }.join(', ')
        end

        # Constructs joins clause
        #
        # @return [String] joins clause
        #
        # @api private
        def join_statement(links, qualify)
          statement = ''

          links.reverse_each do |relationship|
            statement << " INNER JOIN #{quote_name(relationship.source_model.storage_name(name))} ON "
            statement << relationship.target_key.zip(relationship.source_key).map do |target_property, source_property|
              "#{property_to_column_name(target_property, qualify)} = #{property_to_column_name(source_property, qualify)}"
            end.join(' AND ')
          end

          statement
        end

        # Constructs where clause
        #
        # @return [String] where clause
        #
        # @api private
        def conditions_statement(conditions, qualify = false)
          case conditions
            when Conditions::NotOperation
              negate_operation(conditions, qualify)

            when Conditions::AbstractOperation
              # TODO: remove this once conditions can be compressed
              if conditions.operands.size == 1
                # factor out operations with a single operand
                conditions_statement(conditions.operands.first, qualify)
              else
                operation_statement(conditions, qualify)
              end

            when Conditions::AbstractComparison
              comparison_statement(conditions, qualify)

            when Array
              conditions  # handle raw conditions
          end
        end

        # Constructs order clause
        #
        # @return [String] order clause
        #
        # @api private
        def order_statement(order, qualify)
          statements = order.map do |order|
            statement = property_to_column_name(order.property, qualify)
            statement << ' DESC' if order.direction == :desc
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

          operands = operation.operands

          operands.each do |operand|
            statement, values = conditions_statement(operand, qualify)

            if operand.respond_to?(:operands) && operand.operands.size > 1
              statement = "(#{statement})"
            end

            statements << statement
            bind_values.concat(values)
          end

          join_with = operation.kind_of?(@negated ? Conditions::OrOperation : Conditions::AndOperation) ? 'AND' : 'OR'
          statement = statements.join(" #{join_with} ")

          return statement, bind_values
        end

        # Constructs comparison clause
        #
        # @return [String] comparison clause
        #
        # @api private
        def comparison_statement(comparison, qualify)
          value = comparison.value

          # TODO: move exclusive Range handling into another method, and
          # update conditions_statement to use it

          # break exclusive Range queries up into two comparisons ANDed together
          if value.kind_of?(Range) && value.exclude_end?
            operation = Conditions::BooleanOperation.new(:and,
              Conditions::Comparison.new(:gte, comparison.property, value.first),
              Conditions::Comparison.new(:lt,  comparison.property, value.last)
            )

            statement, bind_values = operation_statement(operation, qualify)

            return "(#{statement})", bind_values
          end

          operator = case comparison
            when Conditions::EqualToComparison              then @negated ? inequality_operator(value) : equality_operator(value)
            when Conditions::InclusionComparison            then @negated ? exclude_operator(value)    : include_operator(value)
            when Conditions::RegexpComparison               then @negated ? not_regexp_operator(value) : regexp_operator(value)
            when Conditions::LikeComparison                 then @negated ? unlike_operator(value)     : like_operator(value)
            when Conditions::GreaterThanComparison          then @negated ? '<='                       : '>'
            when Conditions::LessThanComparison             then @negated ? '>='                       : '<'
            when Conditions::GreaterThanOrEqualToComparison then @negated ? '<'                        : '>='
            when Conditions::LessThanOrEqualToComparison    then @negated ? '>'                        : '<='
          end

          return "#{property_to_column_name(comparison.property, qualify)} #{operator} ?", [ value ]
        end

        # TODO: document
        # @api private
        def equality_operator(operand)
          operand.nil? ? 'IS' : '='
        end

        # TODO: document
        # @api private
        def inequality_operator(operand)
          operand.nil? ? 'IS NOT' : '<>'
        end

        # TODO: document
        # @api private
        def include_operator(operand)
          case operand
            when Array then 'IN'
            when Range then 'BETWEEN'
          end
        end

        # TODO: document
        # @api private
        def exclude_operator(operand)
          "NOT #{include_operator(operand)}"
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
          "\"#{name.gsub('"', '""')}\""
        end
      end #module SQL

      include SQL
    end # class DataObjectsAdapter

    const_added(:DataObjectsAdapter)
  end # module Adapters
end # module DataMapper
