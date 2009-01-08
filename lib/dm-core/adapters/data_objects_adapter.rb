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
          repository = resource.repository
          model      = resource.model
          attributes = resource.dirty_attributes

          # TODO: make a model.identity_field method
          identity_field = model.key(repository.name).detect { |p| p.serial? }

          statement = insert_statement(repository, model, attributes.keys, identity_field)
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
            bind_values = query.bind_values.map { |v| v == [] ? [nil] : v }
            reader      = command.execute_reader(*bind_values)

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
        with_connection do |connection|
          command = connection.create_command(select_statement(query))
          command.set_types(query.fields.map { |p| p.primitive })

          begin
            reader = command.execute_reader(*query.bind_values)

            if reader.next!
              query.model.load(reader.values, query)
            end
          ensure
            reader.close if reader
          end
        end
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
          reader = nil

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

      # TODO: clean up once transaction related methods move to dm-more/dm-transactions
      def create_connection
        if within_transaction?
          current_transaction.primitive_for(self).connection
        else
          # DataObjects::Connection.new(uri) will give you back the right
          # driver based on the Uri#scheme.
          DataObjects::Connection.new(@uri)
        end
      end

      # TODO: clean up once transaction related methods move to dm-more/dm-transactions
      def close_connection(connection)
        unless within_transaction? && current_transaction.primitive_for(self).connection == connection
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
        connection = nil
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
          statement = "SELECT #{columns_statement(query)}"
          statement << " FROM #{quote_table_name(query.model.storage_name(query.repository.name))}"
          statement << join_statement(query)                         if query.links.any?
          statement << " WHERE #{where_statement(query)}"            if query.conditions.any?
          statement << " GROUP BY #{group_by_statement(query)}"      if query.unique? && query.fields.any? { |p| p.kind_of?(Property) }
          statement << " ORDER BY #{order_by_statement(query)}"      if query.order.any?
          statement << " LIMIT #{quote_column_value(query.limit)}"   if query.limit
          statement << " OFFSET #{quote_column_value(query.offset)}" if query.offset && query.offset > 0
          statement
        rescue => e
          DataMapper.logger.error("QUERY INVALID: #{query.inspect} (#{e})")
          raise e
        end

        def insert_statement(repository, model, properties, identity_field)
          statement = "INSERT INTO #{quote_table_name(model.storage_name(repository.name))} "

          if supports_default_values? && properties.empty?
            statement << 'DEFAULT VALUES'
          else
            statement << <<-SQL.compress_lines
              (#{properties.map { |p| quote_column_name(p.field) }.join(', ')})
              VALUES
              (#{(['?'] * properties.size).join(', ')})
            SQL
          end

          if supports_returning? && identity_field
            statement << " RETURNING #{quote_column_name(identity_field.field)}"
          end

          statement
        end

        def update_statement(properties, query)
          statement = "UPDATE #{quote_table_name(query.model.storage_name(query.repository.name))}"
          statement << " SET #{properties.map { |p| "#{quote_column_name(p.field)} = ?" }.join(', ')}"
          statement << " WHERE #{where_statement(query)}" if query.conditions.any?
          statement
        end

        def delete_statement(query)
          statement = "DELETE FROM #{quote_table_name(query.model.storage_name(query.repository.name))}"
          statement << " WHERE #{where_statement(query)}" if query.conditions.any?
          statement
        end

        def columns_statement(query)
          qualify    = query.links.any?
          repository = query.repository

          query.fields.map { |p| property_to_column_name(repository, p, qualify) }.join(', ')
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
            statement << " INNER JOIN #{quote_table_name(model.storage_name(query.repository.name))} ON "

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

                statement = ''
                statement << '(' if query.conditions.size > 1
                statement << "#{lt_condition} OR #{gte_condition}"
                statement << ')' if query.conditions.size > 1
                statement
              end
            else
              condition_statement(query, operator, property, bind_value)
            end
          end.join(' AND ')
        end

        def group_by_statement(query)
          repository = query.repository
          qualify    = query.links.any?

          properties = query.fields.select { |p| p.kind_of?(Property) }
          properties.map! { |p| property_to_column_name(repository, p, qualify) }
          properties.join(', ')
        end

        def order_by_statement(query)
          repository = query.repository
          qualify    = query.links.any?

          query.order.map { |i| order_statement(repository, i, qualify) }.join(', ')
        end

        def order_statement(repository, item, qualify)
          case item
            when Property
              property_to_column_name(repository, item, qualify)

            when Query::Direction
              statement = property_to_column_name(repository, item.property, qualify)
              statement << ' DESC' if item.direction == :desc
              statement
          end
        end

        def condition_statement(query, operator, left_condition, right_condition)
          return left_condition if operator == :raw

          repository = query.repository
          qualify    = query.links.any?

          conditions = [ left_condition, right_condition ].map do |condition|
            case condition
              when Property, Query::Path
                property_to_column_name(repository, condition, qualify)

              when Query
                opposite = condition == left_condition ? right_condition : left_condition
                query.merge_subquery(operator, opposite, condition)
                "(#{select_statement(condition)})"

              when Array
                if condition.any? && condition.all? { |p| p.kind_of?(Property) }
                  property_values = condition.map { |p| property_to_column_name(repository, p, qualify) }
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

        def property_to_column_name(repository, property, qualify)
          if qualify
            table_name = property.model.storage_name(repository.name)
            "#{quote_table_name(table_name)}.#{quote_column_name(property.field)}"
          else
            quote_column_name(property.field)
          end
        end

        def escape_name(name)
          name.gsub('"', '""')
        end

        def quote_name(name)
          if name.include?('.')
            escape_name(name).split('.').map { |part| "\"#{part}\"" }.join('.')
          else
            escape_name(name)
          end
        end

        # TODO: once the driver's quoting methods become public, have
        # this method delegate to them instead
        alias quote_table_name quote_name

        # TODO: once the driver's quoting methods become public, have
        # this method delegate to them instead
        alias quote_column_name quote_name

        # TODO: once the driver's quoting methods become public, have
        # this method delegate to them instead
        def quote_column_value(column_value)
          return 'NULL' if column_value.nil?

          case column_value
            when String
              if (integer = column_value.to_i).to_s == column_value
                quote_column_value(integer)
              elsif (float = column_value.to_f).to_s == column_value
                quote_column_value(integer)
              else
                "'#{column_value.gsub("'", "''")}'"
              end
            when DateTime
              quote_column_value(column_value.strftime('%Y-%m-%d %H:%M:%S'))
            when Date
              quote_column_value(column_value.strftime('%Y-%m-%d'))
            when Time
              quote_column_value(column_value.strftime('%Y-%m-%d %H:%M:%S') + ((column_value.usec > 0 ? ".#{column_value.usec.to_s.rjust(6, '0')}" : '')))
            when Integer, Float
              column_value.to_s
            when BigDecimal
              column_value.to_s('F')
            else
              column_value.to_s
          end
        end
      end #module SQL

      include SQL

      # TODO: move to dm-more/dm-migrations
      module Migration
        # TODO: move to dm-more/dm-migrations (if possible)
        def storage_exists?(storage_name)
          statement = <<-SQL.compress_lines
            SELECT COUNT(*)
            FROM "information_schema"."tables"
            WHERE "table_type" = 'BASE TABLE'
            AND "table_schema" = ?
            AND "table_name" = ?
          SQL

          query(statement, schema_name, storage_name).first > 0
        end

        # TODO: move to dm-more/dm-migrations (if possible)
        def field_exists?(storage_name, column_name)
          statement = <<-SQL.compress_lines
            SELECT COUNT(*)
            FROM "information_schema"."columns"
            WHERE "table_schema" = ?
            AND "table_name" = ?
            AND "column_name" = ?
          SQL

          query(statement, schema_name, storage_name, column_name).first > 0
        end

        # TODO: move to dm-more/dm-migrations
        def upgrade_model_storage(repository, model)
          table_name = model.storage_name(repository.name)

          if success = create_model_storage(repository, model)
            return model.properties(repository.name)
          end

          properties = []

          model.properties(repository.name).each do |property|
            schema_hash = property_schema_hash(property)
            next if field_exists?(table_name, schema_hash[:name])
            statement = alter_table_add_column_statement(table_name, schema_hash)
            execute(statement)
            properties << property
          end

          properties
        end

        # TODO: move to dm-more/dm-migrations
        def create_model_storage(repository, model)
          repository_name = repository.name
          properties      = model.properties_with_subclasses(repository_name)

          return false if storage_exists?(model.storage_name(repository_name))
          return false if properties.empty?

          execute(create_table_statement(repository, model, properties))

          (create_index_statements(repository, model) + create_unique_index_statements(repository, model)).each do |sql|
            execute(sql)
          end

          true
        end

        # TODO: move to dm-more/dm-migrations
        def destroy_model_storage(repository, model)
          return true unless supports_drop_table_if_exists? || storage_exists?(model.storage_name(repository.name))
          execute(drop_table_statement(repository, model))
          true
        end

        ##
        # Produces a fresh transaction primitive for this Adapter
        #
        # Used by DataMapper::Transaction to perform its various tasks.
        #
        # @return [Object]
        #   a new Object that responds to :close, :begin, :commit,
        #   :rollback, :rollback_prepared and :prepare
        #
        # TODO: move to dm-more/dm-transaction (if possible)
        def transaction_primitive
          DataObjects::Transaction.create_for_uri(@uri)
        end

        module SQL
#          private  ## This cannot be private for current migrations

          # Adapters that support AUTO INCREMENT fields for CREATE TABLE
          # statements should overwrite this to return true
          #
          # TODO: move to dm-more/dm-migrations
          def supports_serial?
            false
          end

          def supports_drop_table_if_exists?
            false
          end

          def schema_name
            raise NotImplementedError
          end

          # TODO: move to dm-more/dm-migrations
          def alter_table_add_column_statement(table_name, schema_hash)
            "ALTER TABLE #{quote_table_name(table_name)} ADD COLUMN #{property_schema_statement(schema_hash)}"
          end

          # TODO: move to dm-more/dm-migrations
          def create_table_statement(repository, model, properties)
            repository_name = repository.name

            statement = <<-SQL.compress_lines
              CREATE TABLE #{quote_table_name(model.storage_name(repository_name))}
              (#{properties.map { |p| property_schema_statement(property_schema_hash(p)) }.join(', ')},
              PRIMARY KEY(#{ properties.key.map { |p| quote_column_name(p.field) }.join(', ')}))
            SQL

            statement
          end

          # TODO: move to dm-more/dm-migrations
          def drop_table_statement(repository, model)
            if supports_drop_table_if_exists?
              "DROP TABLE IF EXISTS #{quote_table_name(model.storage_name(repository.name))}"
            else
              "DROP TABLE #{quote_table_name(model.storage_name(repository.name))}"
            end
          end

          # TODO: move to dm-more/dm-migrations
          def create_index_statements(repository, model)
            table_name = model.storage_name(repository.name)
            model.properties(repository.name).indexes.map do |index_name, fields|
              <<-SQL.compress_lines
                CREATE INDEX #{quote_column_name("index_#{table_name}_#{index_name}")} ON
                #{quote_table_name(table_name)} (#{fields.map { |f| quote_column_name(f) }.join(', ')})
              SQL
            end
          end

          # TODO: move to dm-more/dm-migrations
          def create_unique_index_statements(repository, model)
            table_name = model.storage_name(repository.name)
            model.properties(repository.name).unique_indexes.map do |index_name, fields|
              <<-SQL.compress_lines
                CREATE UNIQUE INDEX #{quote_column_name("unique_#{table_name}_#{index_name}")} ON
                #{quote_table_name(table_name)} (#{fields.map { |f| quote_column_name(f) }.join(', ')})
              SQL
            end
          end

          # TODO: move to dm-more/dm-migrations
          def property_schema_hash(property)
            schema = (self.class.type_map[property.type] || self.class.type_map[property.primitive]).merge(:name => property.field)

            # TODO: figure out a way to specify the size not be included, even if
            # a default is defined in the typemap
            #  - use this to make it so all TEXT primitive fields do not have size
            if property.primitive == String && schema[:primitive] != 'TEXT'
              schema[:size] = property.length
            elsif property.primitive == BigDecimal || property.primitive == Float
              schema[:precision] = property.precision
              schema[:scale]     = property.scale
            end

            schema[:nullable?] = property.nullable?
            schema[:serial?]   = property.serial?

            if property.default.nil? || property.default.respond_to?(:call)
              # remove the default if the property is not nullable
              schema.delete(:default) unless property.nullable?
            else
              if property.type.respond_to?(:dump)
                schema[:default] = property.type.dump(property.default, property)
              else
                schema[:default] = property.default
              end
            end

            schema
          end

          # TODO: move to dm-more/dm-migrations
          def property_schema_statement(schema)
            statement = quote_column_name(schema[:name])
            statement << " #{schema[:primitive]}"

            if schema[:precision] && schema[:scale]
              statement << "(#{[ :precision, :scale ].map { |k| quote_column_value(schema[k]) }.join(',')})"
            elsif schema[:size]
              statement << "(#{quote_column_value(schema[:size])})"
            end

            statement << ' NOT NULL' unless schema[:nullable?]
            statement << " DEFAULT #{quote_column_value(schema[:default])}" if schema.key?(:default)
            statement
          end
        end # module SQL

        include SQL

        module ClassMethods
          # Default types for all data object based adapters.
          #
          # @return [Hash] default types for data objects adapters.
          #
          # TODO: move to dm-more/dm-migrations
          def type_map
            size      = Property::DEFAULT_LENGTH
            precision = Property::DEFAULT_PRECISION
            scale     = Property::DEFAULT_SCALE_BIGDECIMAL

            @type_map ||= {
              Integer                   => { :primitive => 'INT'                                               },
              String                    => { :primitive => 'VARCHAR', :size => size                            },
              Class                     => { :primitive => 'VARCHAR', :size => size                            },
              BigDecimal                => { :primitive => 'DECIMAL', :precision => precision, :scale => scale },
              Float                     => { :primitive => 'FLOAT',   :precision => precision                  },
              DateTime                  => { :primitive => 'TIMESTAMP'                                         },
              Date                      => { :primitive => 'DATE'                                              },
              Time                      => { :primitive => 'TIMESTAMP'                                         },
              TrueClass                 => { :primitive => 'BOOLEAN'                                           },
              DataMapper::Types::Object => { :primitive => 'TEXT'                                              },
              DataMapper::Types::Text   => { :primitive => 'TEXT'                                              },
            }.freeze
          end
        end # module ClassMethods
      end # module Migration

      include Migration
      extend Migration::ClassMethods

      # TODO: move to dm-more/dm-transaction
      module Transaction
        ##
        # Pushes the given Transaction onto the per thread Transaction stack so
        # that everything done by this Adapter is done within the context of said
        # Transaction.
        #
        # @param [DataMapper::Transaction] transaction
        #   a Transaction to be the 'current' transaction until popped.
        #
        # @return [Array(DataMapper::Transaction)]
        #   the stack of active transactions for the current thread
        #
        # TODO: move to dm-more/dm-transaction
        def push_transaction(transaction)
          transactions(Thread.current) << transaction
        end

        ##
        # Pop the 'current' Transaction from the per thread Transaction stack so
        # that everything done by this Adapter is no longer necessarily within the
        # context of said Transaction.
        #
        # @return [DataMapper::Transaction]
        #   the former 'current' transaction.
        #
        # TODO: move to dm-more/dm-transaction
        def pop_transaction
          transactions(Thread.current).pop
        end

        ##
        # Retrieve the current transaction for this Adapter.
        #
        # Everything done by this Adapter is done within the context of this
        # Transaction.
        #
        # @return [DataMapper::Transaction]
        #   the 'current' transaction for this Adapter.
        #
        # TODO: move to dm-more/dm-transaction
        def current_transaction
          transactions(Thread.current).last
        end

        ##
        # Returns whether we are within a Transaction.
        #
        # @return [TrueClass, FalseClass]
        #   whether we are within a Transaction.
        #
        # TODO: move to dm-more/dm-transaction
        def within_transaction?
          !current_transaction.nil?
        end

        private

        def transactions(thread)
          unless @transactions[thread]
            @transactions.delete_if do |key, value|
              !key.respond_to?(:alive?) || !key.alive?
            end
            @transactions[thread] = []
          end
          @transactions[thread]
        end
      end

      include Transaction
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
