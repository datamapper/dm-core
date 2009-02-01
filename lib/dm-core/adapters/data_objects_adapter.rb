gem 'data_objects', '~>0.9.12'
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
          model          = resource.model
          identity_field = model.identity_field
          attributes     = resource.dirty_attributes

          properties  = []
          bind_values = []

          # make the order of the properties consistent
          model.properties(name).each do |property|
            next unless attributes.key?(property)
            properties  << property
            bind_values << attributes[property]
          end

          statement = insert_statement(model, properties, identity_field)
          result    = execute(statement, *bind_values)

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

        properties  = []
        bind_values = []

        # make the order of the properties consistent
        query.model.properties(name).each do |property|
          next unless attributes.key?(property)
          properties  << property
          bind_values << attributes[property]
        end

        bind_values.concat(query.bind_values)

        statement = update_statement(properties, query)
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

      chainable do
        protected

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

        # TODO: document this
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
        def supports_returning?
          false
        end

        # Adapters that do not support the DEFAULT VALUES syntax for
        # INSERT statements should overwrite this to return false.
        def supports_default_values?
          true
        end

        def select_statement(query)
          fields     = query.fields
          conditions = query.conditions
          limit      = query.limit
          offset     = query.offset
          order      = query.order
          group_by   = nil

          qualify = query.links.any?

          if qualify || query.unique?
            group_by = fields.select { |p| p.kind_of?(Property) }
          end

          unless (limit && limit > 1) || offset > 0 || qualify
            unique = query.model.properties.select { |p| p.unique? }.to_set

            if query.conditions.any? { |o,p,b| o == :eql && unique.include?(p) && (!b.kind_of?(Array) || b.size == 1) }
              order = nil
              limit = nil
            end
          end

          statement = "SELECT #{columns_statement(fields, qualify)}"
          statement << " FROM #{quote_name(query.model.storage_name(name))}"
          statement << join_statement(query.links, qualify)                if qualify
          statement << " WHERE #{where_statement(conditions, qualify)}"    if conditions.any?
          statement << " GROUP BY #{columns_statement(group_by, qualify)}" if group_by && group_by.any?
          statement << " ORDER BY #{order_by_statement(order, qualify)}"   if order && order.any?
          statement << " LIMIT #{quote_value(limit)}"                      if limit
          statement << " OFFSET #{quote_value(offset)}"                    if limit && offset > 0
          statement
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

          if (conditions = query.conditions).any?
            statement << " WHERE #{where_statement(conditions, query.links.any?)}"
          end

          statement
        end

        def delete_statement(query)
          statement = "DELETE FROM #{quote_name(query.model.storage_name(name))}"

          if (conditions = query.conditions).any?
            statement << " WHERE #{where_statement(conditions, query.links.any?)}"
          end

          statement
        end

        def columns_statement(properties, qualify)
          properties.map { |p| property_to_column_name(p, qualify) }.join(', ')
        end

        def join_statement(links, qualify)
          statement = ''

          links.reverse_each do |relationship|
            model = case relationship
              when Associations::ManyToMany::Relationship, Associations::OneToMany::Relationship, Associations::OneToOne::Relationship
                relationship.parent_model
              when Associations::ManyToOne::Relationship
                relationship.child_model
            end

            # We only do INNER JOIN for now
            statement << " INNER JOIN #{quote_name(model.storage_name(name))} ON "

            statement << relationship.parent_key.zip(relationship.child_key).map do |parent_property,child_property|
              condition_statement(:eql, parent_property, child_property, qualify)
            end.join(' AND ')
          end

          statement
        end

        def where_statement(conditions, qualify)
          conditions.map do |operator,property,bind_value|
            # TODO: think about updating Query so that exclusive Range conditions are
            # transformed into AND or OR conditions like below.  Effectively the logic
            # below would be moved into Query

            # handle exclusive range conditions
            if bind_value.kind_of?(Range) && bind_value.exclude_end?
              case operator
                when :eql
                  gte_condition = condition_statement(:gte, property, bind_value.first, qualify)
                  lt_condition  = condition_statement(:lt,  property, bind_value.last,  qualify)

                  "#{gte_condition} AND #{lt_condition}"
                when :not
                  lt_condition  = condition_statement(:lt,  property, bind_value.first, qualify)
                  gte_condition = condition_statement(:gte, property, bind_value.last,  qualify)

                  if conditions.size > 1
                    "(#{lt_condition} OR #{gte_condition})"
                  else
                    "#{lt_condition} OR #{gte_condition}"
                  end
              end
            else
              condition_statement(operator, property, bind_value, qualify)
            end
          end.join(' AND ')
        end

        def order_by_statement(order, qualify)
          order.map { |i| order_statement(i, qualify) }.join(', ')
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

        def condition_statement(operator, left_condition, right_condition, qualify)
          return left_condition if operator == :raw

          conditions = [ left_condition, right_condition ].map do |condition|
            case condition
              when Property, Query::Path
                property_to_column_name(condition, qualify)
              else
                '?'
            end
          end

          comparison = case operator
            when :eql, :in then equality_operator(right_condition)
            when :not      then inequality_operator(right_condition)
            when :like     then like_operator(right_condition)
            when :gt       then '>'
            when :gte      then '>='
            when :lt       then '<'
            when :lte      then '<='
          end

          conditions.join(" #{comparison} ")
        end

        def equality_operator(operand)
          case operand
            when Array, Query then 'IN'
            when Range        then 'BETWEEN'
            when nil          then 'IS'
            else                   '='
          end
        end

        def inequality_operator(operand)
          case operand
            when Array, Query then 'NOT IN'
            when Range        then 'NOT BETWEEN'
            when nil          then 'IS NOT'
            else                   '<>'
          end
        end

        def like_operator(operand)
          operand.kind_of?(Regexp) ? '~' : 'LIKE'
        end

        # TODO: once the driver's quoting methods become public, have
        # this method delegate to them instead
        def quote_name(name)
          escaped = name.gsub('"', '""')

          if escaped.include?('.')
            escaped.split('.').map { |part| "\"#{part}\"" }.join('.')
          else
            "\"#{escaped}\""
          end
        end

        # TODO: once the driver's quoting methods become public, have
        # this method delegate to them instead
        def quote_value(value)
          case value
            when String
              "'#{value.gsub("'", "''")}'"
            when Integer, Float
              value.to_s
            when DateTime
              quote_value(value.strftime('%Y-%m-%d %H:%M:%S'))
            when Date
              quote_value(value.strftime('%Y-%m-%d'))
            when Time
              usec = value.usec
              quote_value(value.strftime('%Y-%m-%d %H:%M:%S') + ((usec > 0 ? ".#{usec.to_s.rjust(6, '0')}" : '')))
            when BigDecimal
              value.to_s('F')
            when nil
              'NULL'
            else
              value.to_s
          end
        end
      end #module SQL

      include SQL
    end # class DataObjectsAdapter

    const_added(:DataObjectsAdapter)
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
