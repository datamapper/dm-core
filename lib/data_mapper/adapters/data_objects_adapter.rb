gem 'addressable', '>=1.0.4'
require 'addressable/uri'

gem 'data_objects', '=0.9.0'
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

        repository.adapter.send(:read_set_with_sql, repository, self, properties, sql, params, do_reload)
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
          tm.map(Fixnum).to('INT')
          tm.map(String).to('VARCHAR').with(:size => Property::DEFAULT_LENGTH)
          tm.map(Class).to('VARCHAR').with(:size => Property::DEFAULT_LENGTH)
          tm.map(DM::Discriminator).to('VARCHAR').with(:size => Property::DEFAULT_LENGTH)
          tm.map(BigDecimal).to('DECIMAL').with(:scale => Property::DEFAULT_SCALE, :precision => Property::DEFAULT_PRECISION)
          tm.map(Float).to('FLOAT').with(:scale => Property::DEFAULT_SCALE, :precision => Property::DEFAULT_PRECISION)
          tm.map(DateTime).to('DATETIME')
          tm.map(Date).to('DATE')
          tm.map(TrueClass).to('BOOLEAN')
          tm.map(Object).to('TEXT')
          tm.map(DM::Text).to('TEXT')
        end
      end

      # all of our CRUD
      # Methods dealing with a single resource object
      def create(repository, resource)
        properties = resource.dirty_attributes

        identity_field = begin
          key = resource.class.key(name)
          key.first if key.size == 1 && key.first.serial?
        end

        statement = create_statement(resource.class, properties, identity_field)
        bind_values = properties.map { |property| resource.instance_variable_get(property.instance_variable_name) }

        result = execute(statement, *bind_values)

        return false if result.to_i != 1

        if identity_field
          resource.instance_variable_set(identity_field.instance_variable_name, result.insert_id)
        end

        true
      end

      def read(repository, model, key)
        properties = model.properties(repository.name).defaults

        properties_with_indexes = Hash[*properties.zip((0...properties.length).to_a).flatten]

        # FIXME: do not use Collection for instantiating a single resource.
        # TODO: Create a Resource class method that instantiates a resource
        # and registers it in the IdentityMap so that Collection#load isn't
        # needed for simple cases like this.
        set = Collection.new(repository, model, properties_with_indexes)

        statement = read_statement(model, properties)

        with_connection do |connection|
          command = connection.create_command(statement)
          command.set_types(properties.map { |property| property.primitive })

          begin
            reader = command.execute_reader(*key)
            set.load(reader.values) if reader.next!
            set.first
          ensure
            reader.close if reader
          end
        end
      end

      def update(repository, resource)
        properties = resource.dirty_attributes

        return false if properties.empty?

        statement = update_statement(resource.class, properties)
        bind_values = properties.map { |property| resource.instance_variable_get(property.instance_variable_name) }
        parameters = (bind_values + resource.key)

        execute(statement, *parameters).to_i == 1
      end

      def delete(repository, resource)
        statement = delete_statement(resource.class)
        key = resource.class.key(name).map { |property| resource.instance_variable_get(property.instance_variable_name) }

        execute(statement, *key).to_i == 1
      end

      # Methods dealing with finding stuff by some query parameters
      def read_set(repository, query)
        read_set_with_sql(repository,
                          query.model,
                          query.fields,
                          query_read_statement(query),
                          query.parameters,
                          query.reload?)
      end

      def upgrade_model_storage(repository, model)
        table_name = model.storage_name(name)

        unless exists?(model.storage_name(name))
          return create_model_storage(repository, model) ? model : nil
        end

        rval = []

        with_connection do |connection|
          model.properties.each do |property|
            schema_hash = property_schema_hash(property, model)
            unless field_exists?(table_name, schema_hash[:name])
              statement = alter_table_add_column_statement(table_name, schema_hash)
              command = connection.create_command(statement)
              result = command.execute_non_query
              rval << property if result.to_i == 1
            end
          end
        end

        rval
      end

      def create_model_storage(repository, model)
        statement = create_table_statement(model)
        execute(statement).to_i == 1
      end

      def destroy_model_storage(repository, model)
        statement = drop_table_statement(model)
        execute(statement).to_i == 1
      end

      # Database-specific method
      def execute(statement, *args)
        with_connection do |connection|
          command = connection.create_command(statement)
          command.execute_non_query(*args)
        end
      end

      def query(statement, *args)
        results = []

        with_reader(statement, *args) do |reader|
          if (fields = reader.fields).size > 1
            fields = fields.map { |field| DataMapper::Inflection.underscore(field).to_sym }
            struct = Struct.new(*fields)

            while(reader.next!) do
              results << struct.new(*reader.values)
            end
          else
            while(reader.next!) do
              results << reader.values.at(0)
            end
          end
        end

        results
      end

      def transaction_primitive
        DataObjects::Transaction.create_for_uri(@uri)
      end

      protected

      def normalize_uri(uri_or_options)
        if String === uri_or_options
          uri_or_options = Addressable::URI.parse(uri_or_options)
        end
        if Addressable::URI === uri_or_options
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

      private

      def initialize(name, uri_or_options)
        super

        # Default the driver-specifc logger to DataMapper's logger
        driver_module = DataObjects.const_get(@uri.scheme.capitalize) rescue nil
        driver_module.logger = DataMapper.logger if driver_module && driver_module.respond_to?(:logger)
      end

      def create_connection
        if within_transaction?
          current_transaction.primitive_for(self).connection
        else
          # DataObjects::Connection.new(uri) will give you back the right
          # driver based on the Uri#scheme.
          DataObjects::Connection.new(@uri)
        end
      end

      def close_connection(connection)
        connection.close unless within_transaction? && current_transaction.primitive_for(self).connection == connection
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

      def with_reader(statement, *params, &block)
        with_connection do |connection|
          reader = nil
          begin
            reader = connection.create_command(statement).execute_reader(*params)
            return yield(reader)
          ensure
            reader.close if reader
          end
        end
      end

      #
      # used by find_by_sql and read_set
      #
      # @param repository<DataMapper::Repository> the repository to read from.
      # @param model<Object>  the class of the instances to read.
      # @param properties<Array>  the properties to read. Must contain Symbols,
      #   Strings or DM::Properties.
      # @param sql<String>  the query to execute.
      # @param parameters<Array>  the conditions to the query.
      # @param do_reload<Boolean> whether to reload objects already found in the
      #   identity map.
      #
      # @return <Collection> a set of the found instances.
      def read_set_with_sql(repository, model, properties, sql, parameters, do_reload)
        properties_with_indexes = Hash[*properties.zip((0...properties.length).to_a).flatten]
        Collection.new(repository, model, properties_with_indexes) do |set|
          with_connection do |connection|
            begin
              command = connection.create_command(sql)
              command.set_types(properties.map { |property| property.primitive })

              reader = command.execute_reader(*parameters)

              while(reader.next!)
                set.load(reader.values, do_reload)
              end
            ensure
              reader.close if reader
            end
          end
        end
      end

      # This model is just for organization. The methods are included into the
      # Adapter below.
      module SQL
        private

        def create_statement(model, properties, identity_field)
          statement = <<-EOS.compress_lines
            INSERT INTO #{quote_table_name(model.storage_name(name))}
            (#{properties.map { |property| quote_column_name(property.field) }.join(', ')})
            VALUES
            (#{(['?'] * properties.size).join(', ')})
          EOS

          if create_with_returning? && identity_field
            statement << " RETURNING #{quote_column_name(identity_field.field)}"
          end

          statement
        end

        # TODO: remove this and use query_read_statement
        def read_statement(model, properties)
          <<-EOS.compress_lines
            SELECT #{properties.map { |property| quote_column_name(property.field) }.join(', ')}
            FROM #{quote_table_name(model.storage_name(name))}
            WHERE #{model.key(name).map { |property| "#{quote_column_name(property.field)} = ?" }.join(' AND ')}
            LIMIT 1
          EOS
        end

        def update_statement(model, properties)
          <<-EOS.compress_lines
            UPDATE #{quote_table_name(model.storage_name(name))}
            SET #{properties.map {|attribute| "#{quote_column_name(attribute.field)} = ?" }.join(', ')}
            WHERE #{model.key(name).map { |property| "#{quote_column_name(property.field)} = ?" }.join(' AND ')}
          EOS
        end

        def delete_statement(model)
          <<-EOS.compress_lines
            DELETE FROM #{quote_table_name(model.storage_name(name))}
            WHERE #{model.key(name).map { |property| "#{quote_column_name(property.field)} = ?" }.join(' AND ')}
          EOS
        end

        # Adapters requiring a RETURNING syntax for create statements
        # should overwrite this to return true.
        def create_with_returning?
          false
        end

        def alter_table_add_column_statement(table_name, schema_hash)
          "ALTER TABLE #{quote_table_name(table_name)} ADD COLUMN #{property_schema_statement(schema_hash)}"
        end

        def create_table_statement(model)
          statement = "CREATE TABLE #{quote_table_name(model.storage_name(name))} ("
          statement << "#{model.properties.collect {|p| property_schema_statement(property_schema_hash(p, model)) } * ', '}"

          if (key = model.properties.key).any?
            statement << ", PRIMARY KEY(#{ key.collect { |p| quote_column_name(p.field) } * ', '})"
          end

          statement << ")"
          statement.compress_lines
        end

        def drop_table_statement(model)
          "DROP TABLE IF EXISTS #{quote_table_name(model.storage_name(name))}"
        end

        def property_schema_hash(property, model)
          schema = self.class.type_map[property.type].merge(:name => property.field)
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

        def relationship_schema_hash(relationship)
          identifier, relationship = relationship

          self.class.type_map[Fixnum].merge(:name => "#{identifier}_id") if identifier == relationship.name
        end

        def relationship_schema_statement(hash)
          property_schema_statement(hash) unless hash.nil?
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

              # We only do LEFT OUTER JOIN for now
              s = ' LEFT OUTER JOIN '
              s << parent_model_name << ' ON '
              parts = []
              relationship.parent_key.zip(child_keys) do |parent_key,child_key|
                part = ' ('
                part <<  property_to_column_name(parent_model_name, parent_key, true)
                part << ' = '
                part <<  property_to_column_name(child_model_name, child_key, true)
                part << ')'
                parts << part
              end
              s << parts.join(' AND ')
              joins << s
            end
            statement << joins.join(' ')
          end

          unless query.conditions.empty?
            statement << ' WHERE '
            statement << '(' if query.conditions.size > 1
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
            end.join(') AND (')
            statement << ')' if query.conditions.size > 1
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
                  direction = item.direction
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
              query.merge_sub_select_conditions(operator, property, bind_value)
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
              query.merge_sub_select_conditions(operator, property, bind_value)
              "#{property_to_column_name(table_name, property, qualify)} NOT IN (#{query_read_statement(bind_value)})"
            else "#{property_to_column_name(table_name, property, qualify)} <> ?"
          end
        end

        def property_to_column_name(table_name, property, qualify)
          if qualify
            quote_table_name(table_name) + '.' + quote_column_name(property.field)
          else
            quote_column_name(property.field)
          end
        end

        # TODO: once the driver's quoting methods become public, have
        # this method delegate to them instead
        def quote_table_name(table_name)
          "\"#{table_name.gsub('"', '""')}\""
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

    end # class DoAdapter
  end # module Adapters
end # module DataMapper
