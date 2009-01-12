gem 'data_objects', '~>0.9.10'
require 'data_objects'

module DataMapper
  module Adapters
    # You must inherit from the DoAdapter, and implement the
    # required methods to adapt a database library for use with the DataMapper.
    #
    # NOTE: By inheriting from DataObjectsAdapter, you get a copy of all the
    # standard sub-modules (Quoting, Coersion and Queries) in your own Adapter.
    # You can extend and overwrite these copies without affecting the originals.
    class DataObjectsAdapter < AbstractAdapter
      ##
      # For each model instance in resources, issues an SQL INSERT
      # (or equivalent) statement to create a new record in the data store for
      # the instance
      #
      # @param [Array] resources
      #   The set of resources (model instances)
      #
      # @return [Integer]
      #   The number of records that were actually saved into the data-store
      #
      # @api semipublic
      def create(resources)
        created = 0
        resources.each do |resource|
          model      = resource.model
          attributes = resource.dirty_attributes

          identity_field = model.identity_field

          statement = insert_statement(model, attributes.keys, identity_field)
          bind_values = attributes.values

          result = execute(statement, *bind_values)

          if result.to_i == 1
            if identity_field
              identity_field.set!(resource, result.insert_id)
            end
            created += 1
          end
        end
        created
      end

      def read_many(query)
        with_connection do |connection|
          command = connection.create_command(select_statement(query))
          command.set_types(query.fields.map { |p| p.primitive })

          begin
            reader = command.execute_reader(*query.bind_values)

            model     = query.model
            resources = []

            while(reader.next!)
              resources << model.load(reader.values, query)
            end

            resources
          ensure
            reader.close if reader
          end
        end
      end

      def read_one(query)
        read_many(query).first
      end

      def update(attributes, query)
        # TODO: if the query contains any links, a limit or an offset
        # use a subselect to get the rows to be updated

        statement = update_statement(attributes.keys, query)
        bind_values = attributes.values + query.bind_values
        execute(statement, *bind_values).to_i
      end

      def delete(query)
        # TODO: if the query contains any links, a limit or an offset
        # use a subselect to get the rows to be deleted

        statement = delete_statement(query)
        execute(statement, *query.bind_values).to_i
      end

      # Database-specific method
      def execute(statement, *bind_values)
        with_connection do |connection|
          command = connection.create_command(statement)
          command.execute_non_query(*bind_values)
        end
      end

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

      def normalize_uri(uri_or_options)
        if uri_or_options.kind_of?(String) || uri_or_options.kind_of?(Addressable::URI)
          uri_or_options = DataObjects::URI.parse(uri_or_options)
        end

        if uri_or_options.kind_of?(DataObjects::URI)
          return uri_or_options
        end

        query = uri_or_options.except(:adapter, :username, :password, :host, :port, :database).map { |pair| pair.join('=') }.join('&')
        query = nil if query.blank?

        return DataObjects::URI.parse(Addressable::URI.new(
          :scheme   => uri_or_options[:adapter].to_s,
          :user     => uri_or_options[:username],
          :password => uri_or_options[:password],
          :host     => uri_or_options[:host],
          :port     => uri_or_options[:port],
          :path     => uri_or_options[:database],
          :query    => query
        ))
      end

      # @api semipublic
      def create_connection
        # DataObjects::Connection.new(uri) will give you back the right
        # driver based on the Uri#scheme.
        DataObjects::Connection.new(@uri)
      end

      # @api semipublic
      def close_connection(connection)
        connection.close
      end

      private

      def initialize(name, uri_or_options)
        super

        # Default the driver-specifc logger to DataMapper's logger
        if driver_module = DataObjects.const_get(@uri.scheme.capitalize) rescue nil
          driver_module.logger = DataMapper.logger if driver_module.respond_to?(:logger=)
        end
      end

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
      module SQL
        private

        # Adapters requiring a RETURNING syntax for INSERT statements
        # should overwrite this to return true.
        def supports_returning?
          false
        end

        # Adapters that do not support the DEFAULT VALUES syntax for
        # INSERT statements should overwrite this to return false.
        def supports_default_values?
          true
        end

        def select_statement(query)
          fields = query.fields
          limit  = query.limit
          offset = query.offset

          statement = "SELECT #{columns_statement(query, fields)}"
          statement << " FROM #{quote_name(query.model.storage_name(name))}"
          statement << join_statement(query)                             if query.links.any?
          statement << " WHERE #{where_statement(query)}"                if query.conditions.any?
          statement << " GROUP BY #{columns_statement(query, group_by)}" if query.unique? && (group_by = fields.select { |p| p.kind_of?(Property) }).any?
          statement << " ORDER BY #{order_by_statement(query)}"          if query.order.any?
          statement << " LIMIT #{quote_value(limit)}"                    if limit
          statement << " OFFSET #{quote_value(offset)}"                  if offset && offset > 0
          statement
        rescue => e
          DataMapper.logger.error("QUERY INVALID: #{query.inspect} (#{e})")
          raise e
        end

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

        def update_statement(properties, query)
          statement = "UPDATE #{quote_name(query.model.storage_name(name))}"
          statement << " SET #{properties.map { |p| "#{quote_name(p.field)} = ?" }.join(', ')}"
          statement << " WHERE #{where_statement(query)}" if query.conditions.any?
          statement
        end

        def delete_statement(query)
          statement = "DELETE FROM #{quote_name(query.model.storage_name(name))}"
          statement << " WHERE #{where_statement(query)}" if query.conditions.any?
          statement
        end

        def columns_statement(query, properties)
          qualify = query.links.any?

          properties.map { |p| property_to_column_name(p, qualify) }.join(', ')
        end

        def join_statement(query)
          statement = ''

          query.links.reverse_each do |relationship|
            model = case relationship
              when Associations::ManyToMany::Relationship, Associations::OneToMany::Relationship, Associations::OneToOne::Relationship
                relationship.parent_model
              when Associations::ManyToOne::Relationship
                relationship.child_model
            end

            # We only do INNER JOIN for now
            statement << " INNER JOIN #{quote_name(model.storage_name(name))} ON "

            statement << relationship.parent_key.zip(relationship.child_key).map do |parent_property,child_property|
              condition_statement(query, :eql, parent_property, child_property)
            end.join(' AND ')
          end

          statement
        end

        def where_statement(query)
          query.conditions.map do |operator,property,bind_value|
            # handle exclusive range conditions
            if bind_value.kind_of?(Range) && bind_value.exclude_end? && (operator == :eql || operator == :not)
              if operator == :eql
                gte_condition = condition_statement(query, :gte, property, bind_value.first)
                lt_condition  = condition_statement(query, :lt,  property, bind_value.last)

                "#{gte_condition} AND #{lt_condition}"
              else
                lt_condition  = condition_statement(query, :lt,  property, bind_value.first)
                gte_condition = condition_statement(query, :gte, property, bind_value.last)

                if query.conditions.size > 1
                  "(#{lt_condition} OR #{gte_condition})"
                else
                  "#{lt_condition} OR #{gte_condition}"
                end
              end
            else
              condition_statement(query, operator, property, bind_value)
            end
          end.join(' AND ')
        end

        def order_by_statement(query)
          qualify = query.links.any?

          query.order.map { |i| order_statement(i, qualify) }.join(', ')
        end

        def order_statement(item, qualify)
          case item
            when Property
              property_to_column_name(item, qualify)

            when Query::Direction
              statement = property_to_column_name(item.property, qualify)
              statement << ' DESC' if item.direction == :desc
              statement
          end
        end

        def condition_statement(query, operator, left_condition, right_condition)
          return left_condition if operator == :raw

          qualify = query.links.any?

          conditions = [ left_condition, right_condition ].map do |condition|
            case condition
              when Property, Query::Path
                property_to_column_name(condition, qualify)

              when Query
                opposite = condition == left_condition ? right_condition : left_condition
                query.merge_subquery(operator, opposite, condition)
                "(#{select_statement(condition)})"

              when Array
                if condition.any? && condition.all? { |p| p.kind_of?(Property) }
                  property_values = condition.map { |p| property_to_column_name(p, qualify) }
                  "(#{property_values.join(', ')})"
                end
            end || '?'
          end

          comparison = case operator
            when :eql, :in then equality_operator(right_condition)
            when :not      then inequality_operator(right_condition)
            when :like     then like_operator(right_condition)
            when :gt       then '>'
            when :gte      then '>='
            when :lt       then '<'
            when :lte      then '<='
            else raise "Invalid query operator: #{operator.inspect}"
          end

          conditions.join(" #{comparison} ")
        end

        def equality_operator(operand)
          case operand
            when Array, Query then 'IN'
            when Range        then 'BETWEEN'
            when NilClass     then 'IS'
            else                   '='
          end
        end

        def inequality_operator(operand)
          case operand
            when Array, Query then 'NOT IN'
            when Range        then 'NOT BETWEEN'
            when NilClass     then 'IS NOT'
            else                   '<>'
          end
        end

        def like_operator(operand)
          operand.kind_of?(Regexp) ? '~' : 'LIKE'
        end

        def property_to_column_name(property, qualify)
          if qualify
            table_name = property.model.storage_name(name)
            "#{quote_name(table_name)}.#{quote_name(property.field)}"
          else
            quote_name(property.field)
          end
        end

        # TODO: once the driver's quoting methods become public, have
        # this method delegate to them instead
        def escape_name(name)
          name.gsub('"', '""')
        end

        # TODO: once the driver's quoting methods become public, have
        # this method delegate to them instead
        def quote_name(name)
          if name.include?('.')
            escape_name(name).split('.').map { |part| "\"#{part}\"" }.join('.')
          else
            escape_name(name)
          end
        end

        # TODO: once the driver's quoting methods become public, have
        # this method delegate to them instead
        def quote_value(value)
          return 'NULL' if value.nil?

          case value
            when String
              if (integer = value.to_i).to_s == value
                quote_value(integer)
              elsif (float = value.to_f).to_s == value
                quote_value(integer)
              else
                "'#{value.gsub("'", "''")}'"
              end
            when DateTime
              quote_value(value.strftime('%Y-%m-%d %H:%M:%S'))
            when Date
              quote_value(value.strftime('%Y-%m-%d'))
            when Time
              quote_value(value.strftime('%Y-%m-%d %H:%M:%S') + ((value.usec > 0 ? ".#{value.usec.to_s.rjust(6, '0')}" : '')))
            when Integer, Float
              value.to_s
            when BigDecimal
              value.to_s('F')
            else
              value.to_s
          end
        end
      end #module SQL

      include SQL
    end # class DataObjectsAdapter
  end # module Adapters

  # TODO: move to dm-ar-finders
  module Model
    #
    # Find instances by manually providing SQL
    #
    # @param sql<String>   an SQL query to execute
    # @param <Array>    an Array containing a String (being the SQL query to
    #   execute) and the parameters to the query.
    #   example: ["SELECT name FROM users WHERE id = ?", id]
    # @param query<DataMapper::Query>  a prepared Query to execute.
    # @param opts<Hash>     an options hash.
    #     :repository<Symbol> the name of the repository to execute the query
    #       in. Defaults to self.default_repository_name.
    #     :reload<Boolean>   whether to reload any instances found that already
    #      exist in the identity map. Defaults to false.
    #     :properties<Array>  the Properties of the instance that the query
    #       loads. Must contain DataMapper::Properties.
    #       Defaults to self.properties.
    #
    # @note
    #   A String, Array or Query is required.
    # @return <Collection> the instance matched by the query.
    #
    # @example
    #   MyClass.find_by_sql(["SELECT id FROM my_classes WHERE county = ?",
    #     selected_county], :properties => MyClass.property[:id],
    #     :repository => :county_repo)
    #
    # @api public
    def find_by_sql(*args)
      sql = nil
      query = nil
      bind_values = []
      properties = nil
      do_reload = false
      repository_name = default_repository_name
      args.each do |arg|
        if arg.kind_of?(String)
          sql = arg
        elsif arg.kind_of?(Array)
          sql = arg.first
          bind_values = arg[1..-1]
        elsif arg.kind_of?(DataMapper::Query)
          query = arg
        elsif arg.kind_of?(Hash)
          repository_name = arg.delete(:repository) if arg.include?(:repository)
          properties = Array(arg.delete(:properties)) if arg.include?(:properties)
          do_reload = arg.delete(:reload) if arg.include?(:reload)
          raise "unknown options to #find_by_sql: #{arg.inspect}" unless arg.empty?
        end
      end

      repository = repository(repository_name)
      raise "#find_by_sql only available for Repositories served by a DataObjectsAdapter" unless repository.adapter.kind_of?(DataMapper::Adapters::DataObjectsAdapter)

      if query
        sql = repository.adapter.send(:select_statement, query)
        bind_values = query.bind_values
      end

      raise "#find_by_sql requires a query of some kind to work" unless sql

      properties ||= self.properties(repository.name)

      Collection.new(Query.new(repository, self)) do |collection|
        repository.adapter.send(:with_connection) do |connection|
          command = connection.create_command(sql)

          begin
            reader = command.execute_reader(*bind_values)

            while(reader.next!)
              collection.load(reader.values)
            end
          ensure
            reader.close if reader
          end
        end
      end
    end
  end # module Model
end # module DataMapper
