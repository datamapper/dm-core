gem 'addressable', '>=1.0.4'
require 'addressable/uri'

gem 'data_objects', '=0.9.1'
require 'data_objects'

module DataMapper

  module Resource

    module ClassMethods
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
      # -
      # @api public
      def find_by_sql(*args)
        sql = nil
        query = nil
        params = []
        properties = nil
        do_reload = false
        repository_name = default_repository_name
        args.each do |arg|
          if arg.is_a?(String)
            sql = arg
          elsif arg.is_a?(Array)
            sql = arg.first
            params = arg[1..-1]
          elsif arg.is_a?(DataMapper::Query)
            query = arg
          elsif arg.is_a?(Hash)
            repository_name = arg.delete(:repository) if arg.include?(:repository)
            properties = Array(arg.delete(:properties)) if arg.include?(:properties)
            do_reload = arg.delete(:reload) if arg.include?(:reload)
            raise "unknown options to #find_by_sql: #{arg.inspect}" unless arg.empty?
          end
        end

        the_repository = repository(repository_name)
        raise "#find_by_sql only available for Repositories served by a DataObjectsAdapter" unless the_repository.adapter.is_a?(DataMapper::Adapters::DataObjectsAdapter)

        if query
          sql = the_repository.adapter.send(:query_read_statement, query)
          params = query.fields
        end

        raise "#find_by_sql requires a query of some kind to work" unless sql

        properties ||= self.properties

        Collection.new(Query.new(repository, self)) do |collection|
          repository.adapter.send(:with_connection) do |connection|
            begin
              command = connection.create_command(sql)

              reader = command.execute_reader(*params)

              while(reader.next!)
                collection.load(reader.values)
              end
            ensure
              reader.close if reader
            end
          end
        end
      end
    end

  end

  module Adapters

    # You must inherit from the DoAdapter, and implement the
    # required methods to adapt a database library for use with the DataMapper.
    #
    # NOTE: By inheriting from DataObjectsAdapter, you get a copy of all the
    # standard sub-modules (Quoting, Coersion and Queries) in your own Adapter.
    # You can extend and overwrite these copies without affecting the originals.
    class DataObjectsAdapter < AbstractAdapter

      # Default TypeMap for all data object based adapters.
      #
      # @return <DataMapper::TypeMap> default TypeMap for data objects adapters.
      def self.type_map
        @type_map ||= TypeMap.new(super) do |tm|
          tm.map(Integer).to('INT')
          tm.map(String).to('VARCHAR').with(:size => Property::DEFAULT_LENGTH)
          tm.map(Class).to('VARCHAR').with(:size => Property::DEFAULT_LENGTH)
          tm.map(DM::Discriminator).to('VARCHAR').with(:size => Property::DEFAULT_LENGTH)
          tm.map(BigDecimal).to('DECIMAL').with(:scale => Property::DEFAULT_SCALE, :precision => Property::DEFAULT_PRECISION)
          tm.map(Float).to('FLOAT').with(:scale => Property::DEFAULT_SCALE, :precision => Property::DEFAULT_PRECISION)
          tm.map(DateTime).to('DATETIME')
          tm.map(Date).to('DATE')
          tm.map(Time).to('TIMESTAMP')
          tm.map(TrueClass).to('BOOLEAN')
          tm.map(Object).to('TEXT')
          tm.map(DM::Text).to('TEXT')
        end
      end

      # all of our CRUD
      # Methods dealing with a single resource object
      def create(repository, resource)
        dirty_attributes = resource.dirty_attributes

        identity_field = begin
          key = resource.class.key(name)
          key.first if key.size == 1 && key.first.serial?
        end

        statement = create_statement(resource.class, dirty_attributes, identity_field)
        bind_values = dirty_attributes.map { |p| resource.instance_variable_get(p.instance_variable_name) }

        result = execute(statement, *bind_values)

        return false if result.to_i != 1

        if identity_field
          resource.instance_variable_set(identity_field.instance_variable_name, result.insert_id)
        end

        true
      end

      #def read(repository, model, bind_values)
      #  properties = model.properties(name).defaults
      #
      #  key = model.key(name)
      #
      #  # FIXME: do not use Collection for instantiating a single resource.
      #  # TODO: Create a Resource class method that instantiates a resource
      #  # and registers it in the IdentityMap so that Collection#load isn't
      #  # needed for simple cases like this.
      #  collection = Collection.new(Query.new(repository, model, model.key(name) => bind_values))
      #
      #  statement = read_statement(model, properties, key)
      #
      #  with_connection do |connection|
      #    command = connection.create_command(statement)
      #    command.set_types(properties.map { |p| p.primitive })
      #
      #    begin
      #      reader = command.execute_reader(*bind_values)
      #      collection.load(reader.values) if reader.next!
      #      collection.first
      #    ensure
      #      reader.close if reader
      #    end
      #  end
      #end

      def update(repository, resource)
        # FIXME: if the properties are in different repositories
        # won't this cause problems?
        dirty_attributes = resource.dirty_attributes

        return false if dirty_attributes.empty?

        key = resource.class.key(name)

        statement = update_statement(resource.class, dirty_attributes, key)
        bind_values = dirty_attributes.map { |p| resource.instance_variable_get(p.instance_variable_name) }
        key.each { |p| bind_values << resource.instance_variable_get(p.instance_variable_name) }

        execute(statement, *bind_values).to_i == 1
      end

      def delete(repository, resource)
        key = resource.class.key(name)

        statement = delete_statement(resource.class, key)
        bind_values = key.map { |p| resource.instance_variable_get(p.instance_variable_name) }

        execute(statement, *bind_values).to_i == 1
      end

      # Methods dealing with finding stuff by some query parameters
      def read_set(repository, query)
        Collection.new(query) do |collection|
          with_connection do |connection|
            begin
              command = connection.create_command(query_read_statement(query))
              command.set_types(query.fields.map { |p| p.primitive })

              reader = command.execute_reader(*query.bind_values)

              while(reader.next!)
                collection.load(reader.values)
              end
            ensure
              reader.close if reader
            end
          end
        end
      end

      # Database-specific method
      def execute(statement, *bind_values)
        with_connection do |connection|
          command = connection.create_command(statement)
          command.execute_non_query(*bind_values)
        end
      end

      def query(statement, *args)
        with_reader(statement, *args) do |reader|
          results = []

          if (fields = reader.fields).size > 1
            fields = fields.map { |field| Extlib::Inflection.underscore(field).to_sym }
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
        end
      end

      # TODO: move to dm-more/dm-migrations
      def upgrade_model_storage(repository, model)
        table_name = model.storage_name(name)

        if success = create_model_storage(repository, model)
          return model.properties(name)
        end

        properties = []

        model.properties(name).each do |property|
          schema_hash = property_schema_hash(property, model)
          next if field_exists?(table_name, schema_hash[:name])
          statement = alter_table_add_column_statement(table_name, schema_hash)
          execute(statement)
          properties << property
        end

        properties
      end

      # TODO: move to dm-more/dm-migrations
      def create_model_storage(repository, model)
        return false if storage_exists?(model.storage_name(name))

        execute(create_table_statement(model))

        (create_index_statements(model) + create_unique_index_statements(model)).each do |sql|
          execute(sql)
        end

        true
      end

      # TODO: move to dm-more/dm-migrations
      def destroy_model_storage(repository, model)
        execute(drop_table_statement(model))
        true
      end

      # TODO: move to dm-more/dm-transactions
      def transaction_primitive
        DataObjects::Transaction.create_for_uri(@uri)
      end

      protected

      def normalize_uri(uri_or_options)
        if uri_or_options.kind_of?(String)
          uri_or_options = Addressable::URI.parse(uri_or_options)
        end
        if uri_or_options.kind_of?(Addressable::URI)
          return uri_or_options.normalize
        end

        adapter = uri_or_options.delete(:adapter)
        user = uri_or_options.delete(:username)
        password = uri_or_options.delete(:password)
        host = (uri_or_options.delete(:host) || "")
        port = uri_or_options.delete(:port)
        database = uri_or_options.delete(:database)
        query = uri_or_options.to_a.map { |pair| pair.join('=') }.join('&')
        query = nil if query == ""

        return Addressable::URI.new(
          adapter, user, password, host, port, database, query, nil
        )
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
        connection.close unless within_transaction? && current_transaction.primitive_for(self).connection == connection
      end

      private

      def initialize(name, uri_or_options)
        super

        # Default the driver-specifc logger to DataMapper's logger
        if driver_module = DataObjects.const_get(@uri.scheme.capitalize) rescue nil
          driver_module.logger = DataMapper.logger if driver_module.respond_to?(:logger=)
        end
      end

      def with_connection(&block)
        connection = nil
        begin
          connection = create_connection
          return yield(connection)
        rescue => e
          DataMapper.logger.error(e)
          raise e
        ensure
          close_connection(connection) if connection
        end
      end

      def with_reader(statement, *bind_values, &block)
        with_connection do |connection|
          reader = nil
          begin
            reader = connection.create_command(statement).execute_reader(*bind_values)
            return yield(reader)
          ensure
            reader.close if reader
          end
        end
      end

      # This model is just for organization. The methods are included into the
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

        def create_statement(model, dirty_attributes, identity_field)
          statement = "INSERT INTO #{quote_table_name(model.storage_name(name))} "

          if dirty_attributes.empty? && supports_default_values?
            statement << 'DEFAULT VALUES'
          else
            statement << <<-EOS.compress_lines
              (#{dirty_attributes.map { |p| quote_column_name(p.field(name)) }.join(', ')})
              VALUES
              (#{(['?'] * dirty_attributes.size).join(', ')})
            EOS
          end

          if supports_returning? && identity_field
            statement << " RETURNING #{quote_column_name(identity_field.field(name))}"
          end

          statement
        end

        # TODO: remove this and use query_read_statement instead
        def read_statement(model, properties, key)
          <<-EOS.compress_lines
            SELECT #{properties.map { |p| quote_column_name(p.field(name)) }.join(', ')}
            FROM #{quote_table_name(model.storage_name(name))}
            WHERE #{key.map { |p| "#{quote_column_name(p.field(name))} = ?" }.join(' AND ')}
            LIMIT 1
          EOS
        end

        def update_statement(model, dirty_attributes, key)
          <<-EOS.compress_lines
            UPDATE #{quote_table_name(model.storage_name(name))}
            SET #{dirty_attributes.map { |p| "#{quote_column_name(p.field(name))} = ?" }.join(', ')}
            WHERE #{key.map { |p| "#{quote_column_name(p.field(name))} = ?" }.join(' AND ')}
          EOS
        end

        def delete_statement(model, key)
          <<-EOS.compress_lines
            DELETE FROM #{quote_table_name(model.storage_name(name))}
            WHERE #{key.map { |p| "#{quote_column_name(p.field(name))} = ?" }.join(' AND ')}
          EOS
        end

        def query_read_statement(query)
          qualify = query.links.any?

          statement = 'SELECT '

          statement << query.fields.map do |property|
            # TODO Should we raise an error if there is no such property in the
            #      repository of the query?
            #
            #if property.model.properties(name)[property.name].nil?
            #  raise "Property #{property.model.to_s}.#{property.name.to_s} not available in repository #{name}."
            #end
            #
            table_name = property.model.storage_name(name)
            property_to_column_name(table_name, property, qualify)
          end.join(', ')

          statement << ' FROM ' << quote_table_name(query.model.storage_name(name))

          unless query.links.empty?
            joins = []

            query.links.each do |relationship|
              child_model       = relationship.child_model
              parent_model      = relationship.parent_model
              child_model_name  = child_model.storage_name(name)
              parent_model_name = parent_model.storage_name(name)
              child_keys        = relationship.child_key.to_a

              parent_table_name = quote_table_name(parent_model_name)
              child_table_name = quote_table_name(child_model_name)

              join_table_name = quote_table_name(query.model.storage_name(name)) == parent_table_name ?
                                child_table_name :
                                parent_table_name

              # We only do LEFT OUTER JOIN for now
              s = ' LEFT OUTER JOIN '
              s << join_table_name << ' ON '
              parts = []
              relationship.parent_key.zip(child_keys) do |parent_key,child_key|
                part = ''
#                part = '('  # TODO: uncomment if OR conditions become possible (for links)
                part <<  property_to_column_name(parent_model_name, parent_key, qualify)
                part << ' = '
                part <<  property_to_column_name(child_model_name, child_key, qualify)
#                part << ')'  # TODO: uncomment if OR conditions become possible (for links)
                parts << part
              end
              s << parts.join(' AND ')
              joins << s
            end
            statement << joins.join
          end

          unless query.conditions.empty?
            statement << ' WHERE '
#            statement << '(' if query.conditions.size > 1  # TODO: uncomment if OR conditions become possible (for conditions)
            statement << query.conditions.map do |operator, property, bind_value|
              # TODO Should we raise an error if there is no such property in
              #      the repository of the query?
              #
              #if property.model.properties(name)[property.name].nil?
              #  raise "Property #{property.model.to_s}.#{property.name.to_s} not available in repository #{name}."
              #end
              #
              table_name = property.model.storage_name(name) if property && property.respond_to?(:model)
              case operator
                when :raw      then property
                when :eql, :in then equality_operator(query, table_name, operator, property, qualify, bind_value)
                when :not      then inequality_operator(query, table_name,operator, property, qualify, bind_value)
                when :like     then "#{property_to_column_name(table_name, property, qualify)} LIKE ?"
                when :gt       then "#{property_to_column_name(table_name, property, qualify)} > ?"
                when :gte      then "#{property_to_column_name(table_name, property, qualify)} >= ?"
                when :lt       then "#{property_to_column_name(table_name, property, qualify)} < ?"
                when :lte      then "#{property_to_column_name(table_name, property, qualify)} <= ?"
                else raise "Invalid query operator: #{operator.inspect}"
              end
            end.join(' AND ')
#            end.join(') AND (')                            # TODO: uncomment if OR conditions become possible (for conditions)
#            statement << ')' if query.conditions.size > 1  # TODO: uncomment if OR conditions become possible (for conditions)
          end

          unless query.order.empty?
            parts = []
            query.order.each do |item|
              property, direction = nil, nil

              case item
                when DataMapper::Property
                  property = item
                when DataMapper::Query::Direction
                  property  = item.property
                  direction = item.direction if item.direction == :desc
              end

              table_name = property.model.storage_name(name) if property && property.respond_to?(:model)

              order = property_to_column_name(table_name, property, qualify)
              order << " #{direction.to_s.upcase}" if direction

              parts << order
            end
            statement << " ORDER BY #{parts.join(', ')}"
          end

          statement << " LIMIT #{query.limit}" if query.limit
          statement << " OFFSET #{query.offset}" if query.offset && query.offset > 0

          statement
        rescue => e
          DataMapper.logger.error("QUERY INVALID: #{query.inspect} (#{e})")
          raise e
        end

        def equality_operator(query, table_name, operator, property, qualify, bind_value)
          case bind_value
            when Array             then "#{property_to_column_name(table_name, property, qualify)} IN ?"
            when Range             then "#{property_to_column_name(table_name, property, qualify)} BETWEEN ?"
            when NilClass          then "#{property_to_column_name(table_name, property, qualify)} IS ?"
            when DataMapper::Query then
              query.merge_subquery(operator, property, bind_value)
              # TODO: make it possible for property to be an Array, and then
              #   wrap the columns in parenthesis, eg:  (a, b, c) IN(SELECT a, b, c FROM ...)
              "#{property_to_column_name(table_name, property, qualify)} IN (#{query_read_statement(bind_value)})"
            else "#{property_to_column_name(table_name, property, qualify)} = ?"
          end
        end

        def inequality_operator(query, table_name, operator, property, qualify, bind_value)
          case bind_value
            when Array             then "#{property_to_column_name(table_name, property, qualify)} NOT IN ?"
            when Range             then "#{property_to_column_name(table_name, property, qualify)} NOT BETWEEN ?"
            when NilClass          then "#{property_to_column_name(table_name, property, qualify)} IS NOT ?"
            when DataMapper::Query then
              query.merge_subquery(operator, property, bind_value)
              # TODO: make it possible for property to be an Array, and then
              #   wrap the columns in parenthesis, eg:  (a, b, c) IN(SELECT a, b, c FROM ...)
              "#{property_to_column_name(table_name, property, qualify)} NOT IN (#{query_read_statement(bind_value)})"
            else "#{property_to_column_name(table_name, property, qualify)} <> ?"
          end
        end

        def property_to_column_name(table_name, property, qualify)
          if qualify
            quote_table_name(table_name) + '.' + quote_column_name(property.field(name))
          else
            quote_column_name(property.field(name))
          end
        end

        # TODO: once the driver's quoting methods become public, have
        # this method delegate to them instead
        def quote_table_name(table_name)
          table_name.gsub('"', '""').split('.').map { |part| "\"#{part}\"" }.join('.')
        end

        # TODO: once the driver's quoting methods become public, have
        # this method delegate to them instead
        def quote_column_name(column_name)
          "\"#{column_name.gsub('"', '""')}\""
        end

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

        # Adapters that support AUTO INCREMENT fields for CREATE TABLE
        # statements should overwrite this to return true
        #
        # TODO: move to dm-more/dm-migrations
        def supports_serial?
          false
        end

        # TODO: move to dm-more/dm-migrations
        def alter_table_add_column_statement(table_name, schema_hash)
          "ALTER TABLE #{quote_table_name(table_name)} ADD COLUMN #{property_schema_statement(schema_hash)}"
        end

        # TODO: move to dm-more/dm-migrations
        def create_table_statement(model)
          statement = "CREATE TABLE #{quote_table_name(model.storage_name(name))} ("
          statement << "#{model.properties(name).collect { |p| property_schema_statement(property_schema_hash(p, model)) } * ', '}"

          if (key = model.key(name)).any?
            statement << ", PRIMARY KEY(#{ key.collect { |p| quote_column_name(p.field(name)) } * ', '})"
          end

          statement << ')'
          statement.compress_lines
        end

        # TODO: move to dm-more/dm-migrations
        def drop_table_statement(model)
          "DROP TABLE IF EXISTS #{quote_table_name(model.storage_name(name))}"
        end

        # TODO: move to dm-more/dm-migrations
        def create_index_statements(model)
          table_name = model.storage_name(name)
          model.properties.indexes.collect do |index_name, properties|
            "CREATE INDEX #{quote_column_name('index_' + table_name + '_' + index_name)} ON " +
            "#{quote_table_name(table_name)} (#{properties.collect{|p| quote_column_name(p)}.join ','})"
          end
        end

        # TODO: move to dm-more/dm-migrations
        def create_unique_index_statements(model)
          table_name = model.storage_name(name)
          model.properties.unique_indexes.collect do |index_name, properties|
            "CREATE UNIQUE INDEX #{quote_column_name('unique_index_' + table_name + '_' + index_name)} ON " +
            "#{quote_table_name(table_name)} (#{properties.collect{|p| quote_column_name(p)}.join ','})"
          end
        end

        # TODO: move to dm-more/dm-migrations
        def property_schema_hash(property, model)
          schema = self.class.type_map[property.type].merge(:name => property.field(name))
          # TODO: figure out a way to specify the size not be included, even if
          # a default is defined in the typemap
          #  - use this to make it so all TEXT primitive fields do not have size
          if property.primitive == String && schema[:primitive] != 'TEXT'
            schema[:size] = property.length
          elsif property.primitive == BigDecimal || property.primitive == Float
            schema[:scale]     = property.scale
            schema[:precision] = property.precision
          end

          schema[:nullable?] = property.nullable?
          schema[:serial?]   = property.serial?
          schema[:default]   = property.default unless property.default.nil? || property.default.respond_to?(:call)

          schema
        end

        # TODO: move to dm-more/dm-migrations
        def property_schema_statement(schema)
          statement = quote_column_name(schema[:name])
          statement << " #{schema[:primitive]}"

          if schema[:scale] && schema[:precision]
            statement << "(#{schema[:scale]},#{schema[:precision]})"
          elsif schema[:size]
            statement << "(#{schema[:size]})"
          end

          statement << ' NOT NULL' unless schema[:nullable?]
          statement << " DEFAULT #{quote_column_value(schema[:default])}" if schema.has_key?(:default)
          statement
        end

        # TODO: move to dm-more/dm-migrations
        def relationship_schema_hash(relationship)
          identifier, relationship = relationship

          self.class.type_map[Integer].merge(:name => "#{identifier}_id") if identifier == relationship.name
        end

        # TODO: move to dm-more/dm-migrations
        def relationship_schema_statement(hash)
          property_schema_statement(hash) unless hash.nil?
        end
      end #module SQL

      include SQL

    end # class DoAdapter
  end # module Adapters
end # module DataMapper
