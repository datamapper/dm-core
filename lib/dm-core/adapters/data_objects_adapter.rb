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
            group_by = fields.select { |property| property.kind_of?(Property) }
          end

          unless (limit && limit > 1) || offset > 0 || qualify
            # TODO: move this method to Query, so that it walks the conditions
            # and finds an OR operator

            # TODO: handle cases where two or more properties need to be
            # used together to be unique

            # if a unique property is used, and there is no OR operator, then an ORDER
            # and LIMIT are unecessary because it should only return a single row
            if conditions.kind_of?(Query::Conditions::AndOperation) &&
               conditions.any? { |operand| operand.kind_of?(Query::Conditions::EqualToComparison) && operand.subject.respond_to?(:unique?) && operand.subject.unique? } &&
               !conditions.any? { |operand| operand.kind_of?(Query::Conditions::OrOperation) }
              order = nil
              limit = nil
            end
          end

          conditions_statement, bind_values = conditions_statement(conditions, qualify)

          statement = "SELECT #{columns_statement(fields, qualify)}"
          statement << " FROM #{quote_name(model.storage_name(name))}"
          statement << join_statement(query, qualify)                      if qualify
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
              (#{properties.map { |property| quote_name(property.field) }.join(', ')})
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
        # @return [String] list of fields as a string
        def columns_statement(properties, qualify)
          properties.map { |property| property_to_column_name(property, qualify) }.join(', ')
        end

        # Constructs joins clause
        #
        # @return [String] joins clause
        #
        # @api private
        def join_statement(query, qualify)
          # get the model of origin for the query.
          joined_models = [query.model]

          statement = ''

          # Find out which direction to traverse the linkages
          # by inspecting the head of links (the list of matching pairs stored)
          iterator = (query.links.first.source_model == query.model ? :each : :reverse_each)

          query.links.send(iterator) do |relationship|
            # Find out which end/model of the linkage is already part of the join
            # so that we may join the other end/model to the query.
            model_to_join =
              if joined_models.include? relationship.source_model
                relationship.target_model
              elsif joined_models.include? relationship.target_model
                relationship.source_model
              else
                # and explode if neither model is related to the models already involved in the join
                raise ArgumentError, "Unable to connect the relationship #{relationship.source_model} <-> #{relationship.target_model}) to any of the models already in the query (#{models_in_join.join(", ")}). Check the list of relationship links to ensure that they are being traversed correctly"
              end

            # find the name of the
            statement << " INNER JOIN #{quote_name(model_to_join.storage_name(name))} ON "
            statement << relationship.target_key.zip(relationship.source_key).map do |target_property, source_property|
              "#{property_to_column_name(target_property, qualify)} = #{property_to_column_name(source_property, qualify)}"
            end.join(' AND ')

            # add our model to the list of candidate models that we can join on.
            joined_models << model_to_join
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
              conditions  # handle raw conditions
          end
        end

        # Constructs order clause
        #
        # @return [String] order clause
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
        # @return [String] comparison clause
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
          elsif comparison.subject.kind_of?(Associations::Relationship)
            conditions = foreign_key_conditions(comparison)
            return conditions_statement(conditions, qualify)
          end

          operator = case comparison
            when Query::Conditions::EqualToComparison              then @negated ? inequality_operator(value) : equality_operator(value)
            when Query::Conditions::InclusionComparison            then @negated ? exclude_operator(value)    : include_operator(value)
            when Query::Conditions::RegexpComparison               then @negated ? not_regexp_operator(value) : regexp_operator(value)
            when Query::Conditions::LikeComparison                 then @negated ? unlike_operator(value)     : like_operator(value)
            when Query::Conditions::GreaterThanComparison          then @negated ? '<='                       : '>'
            when Query::Conditions::LessThanComparison             then @negated ? '>='                       : '<'
            when Query::Conditions::GreaterThanOrEqualToComparison then @negated ? '<'                        : '>='
            when Query::Conditions::LessThanOrEqualToComparison    then @negated ? '>'                        : '<='
          end

          return "#{property_to_column_name(comparison.subject, qualify)} #{operator} ?", [ value ]
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
          "\"#{name[0, self.class::IDENTIFIER_MAX_LENGTH].gsub('"', '""')}\""
        end
      end #module SQL

      include SQL
    end # class DataObjectsAdapter

    const_added(:DataObjectsAdapter)
  end # module Adapters
end # module DataMapper
