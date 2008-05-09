begin
  require 'fastthread'
rescue LoadError
end

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
      # ==== Parameters
      # <String>:: An SQL query to execute
      # <Array>:: An Array containing a String (being the SQL query to execute) and the parameters to the query.
      #   example: ["SELECT name FROM users WHERE id = ?", id]
      # <DataMapper::Query>:: A prepared Query to execute.
      # <Hash>:: An options hash.
      #
      # A String, Array or Query is required.
      #
      # ==== Options (the options hash)
      # :repository<Symbol>:: The name of the repository to execute the query in. Defaults to self.default_repository_name.
      # :reload<Boolean>:: Whether to reload any instances found that allready exist in the identity map. Defaults to false.
      # :properties<Array>:: The Properties of the instance that the query loads. Must contain DataMapper::Properties. Defaults to self.properties.
      #
      # ==== Returns
      # Collection:: The instance matched by the query.
      #
      # ==== Example
      # MyClass.find_by_sql(["SELECT id FROM my_classes WHERE county = ?", selected_county], :properties => MyClass.property[:id], :repository => :county_repo)
      #
      # -
      # @public
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
          sql = the_repository.adapter.query_read_statement(query)
          params = query.fields
        end

        raise "#find_by_sql requires a query of some kind to work" unless sql

        properties ||= self.properties

        DataMapper.logger.debug("FIND_BY_SQL: #{sql}  PARAMETERS: #{params.inspect}")

        repository.adapter.read_set_with_sql(repository, self, properties, sql, params, do_reload)
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
      # ==== Returns
      # DataMapper::TypeMap:: default TypeMap for data object adapters.
      def self.type_map
        @type_map ||= TypeMap.new(super) do |tm|
          tm.map(Fixnum).to('INT')
          tm.map(String).to('VARCHAR').with(:size => Property::DEFAULT_LENGTH)
          tm.map(Class).to('VARCHAR').with(:size => Property::DEFAULT_LENGTH)
          tm.map(BigDecimal).to('DECIMAL').with(:precision => Property::DEFAULT_PRECISION, :scale => Property::DEFAULT_SCALE)
          tm.map(Float).to('FLOAT')
          tm.map(DateTime).to('DATETIME')
          tm.map(Date).to('DATE')
          tm.map(TrueClass).to('BOOLEAN')
          tm.map(Object).to('TEXT')
          tm.map(DM::Text).to('TEXT')
        end
      end
      
      def initialize(name, uri_or_options)
        super
        
        # Default the driver-specifc logger to DataMapper's logger
        driver_module = DataObjects.const_get(@uri.scheme.capitalize) rescue nil
        driver_module.logger = DataMapper.logger if driver_module && driver_module.respond_to?(:logger)
      end

      def transaction_primitive
        DataObjects::Transaction.create_for_uri(@uri)
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

      def create_with_returning?
        false
      end

      # all of our CRUD
      # Methods dealing with a single resource object
      def create(repository, resource)
        properties = resource.dirty_attributes

        sql = send(create_with_returning? ? :create_statement_with_returning : :create_statement, resource.class, properties)
        values = properties.map { |property| resource.instance_variable_get(property.instance_variable_name) }
        DataMapper.logger.debug("CREATE: #{sql}  PARAMETERS: #{values.inspect}")

        connection = create_connection
        command = connection.create_command(sql)
        result = command.execute_non_query(*values)

        return false if result.to_i != 1

        key = resource.class.key(name)
        if key.size == 1 && (identity_field = key.first).serial?
          resource.instance_variable_set(identity_field.instance_variable_name, result.insert_id)
        end

        true
      ensure
        close_connection(connection) if connection
      end

      def exists?(storage_name)
        raise NotImplementedError
      end

      def read(repository, resource, key)
        properties = resource.properties(repository.name).defaults

        properties_with_indexes = Hash[*properties.zip((0...properties.length).to_a).flatten]
        set = Collection.new(repository, resource, properties_with_indexes)

        sql = read_statement(resource, key)
        DataMapper.logger.debug("READ: #{sql}  KEY: #{key.inspect}")

        connection = create_connection
        command = connection.create_command(sql)
        command.set_types(properties.map { |property| property.primitive })
        reader = command.execute_reader(*key)

        while(reader.next!)
          set.load(reader.values)
        end

        set.first
      ensure
        reader.close if reader
        close_connection(connection) if connection
      end

      def update(repository, resource)
        properties = resource.dirty_attributes

        return false if properties.empty?

        sql = update_statement(resource.class, properties)
        values = properties.map { |property| resource.instance_variable_get(property.instance_variable_name) }
        parameters = (values + resource.key)
        DataMapper.logger.debug("UPDATE: #{sql}  PARAMETERS: #{parameters.inspect}")

        begin
          connection = create_connection
          command = connection.create_command(sql)

          affected_rows = command.execute_non_query(*parameters).to_i
        ensure
          close_connection(connection) if connection
        end

        affected_rows == 1
      end

      def delete(repository, resource)
        key = resource.class.key(name).map { |property| resource.instance_variable_get(property.instance_variable_name) }

        connection = create_connection
        command = connection.create_command(delete_statement(resource.class))
        affected_rows = command.execute_non_query(*key).to_i

        affected_rows == 1
      ensure
        close_connection(connection) if connection
      end

      def create_model_storage(repository, model)
        sql = create_table_statement(model)

        DataMapper.logger.debug "CREATE TABLE: #{sql}"

        connection = create_connection
        command = connection.create_command(sql)
        result = command.execute_non_query

        result.to_i == 1
      ensure
        close_connection(connection) if connection
      end

      def destroy_model_storage(repository, model)
        sql = drop_table_statement(model)

        DataMapper.logger.debug "DROP TABLE: #{sql}"

        connection = create_connection
        command = connection.create_command(sql)
        result = command.execute_non_query

        result.to_i == 1
      ensure
        close_connection(connection) if connection
      end

      #
      # used by find_by_sql and read_set
      #
      # ==== Parameters
      # repository<DataMapper::Repository>:: The repository to read from.
      # model<Object>:: The class of the instances to read.
      # properties<Array>:: The properties to read. Must contain Symbols, Strings or DM::Properties.
      # sql<String>:: The query to execute.
      # parameters<Array>:: The conditions to the query.
      # do_reload<Boolean>:: Whether to reload objects already found in the identity map.
      #
      # ==== Returns
      # Collection:: A set of the found instances.
      #
      def read_set_with_sql(repository, model, properties, sql, parameters, do_reload)
        properties_with_indexes = Hash[*properties.zip((0...properties.length).to_a).flatten]
        Collection.new(repository, model, properties_with_indexes) do |set|
          DataMapper.logger.debug("READ_SET: #{sql}  PARAMETERS: #{parameters.inspect}")

          begin
            connection = create_connection
            command = connection.create_command(sql)
            command.set_types(properties.map { |property| property.primitive })

            reader = command.execute_reader(*parameters)

            while(reader.next!)
              set.load(reader.values, do_reload)
            end

          rescue StandardError => se
            raise se
          ensure
            reader.close if reader
            close_connection(connection) if connection
          end
        end
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

      def delete_set(repository, query)
        raise NotImplementedError
      end

      # Database-specific method
      def execute(sql, *args)
        DataMapper.logger.debug("EXECUTE: #{sql}  PARAMETERS: #{args.inspect}")

        connection = create_connection
        command = connection.create_command(sql)
        return command.execute_non_query(*args)
      rescue => e
        DataMapper.logger.error(e) if DataMapper.logger
        raise e
      ensure
        connection.close if connection
      end

      def query(sql, *args)
        DataMapper.logger.debug("QUERY: #{sql}  PARAMETERS: #{args.inspect}")

        connection = create_connection
        command = connection.create_command(sql)

        reader = command.execute_reader(*args)
        results = []

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

        return results
      rescue => e
        DataMapper.logger.error(e) if DataMapper.logger
        raise e
      ensure
        reader.close if reader
        connection.close if connection
      end

      # This model is just for organization. The methods are included into the Adapter below.
      module SQL
        def create_statement(model, properties)
          <<-EOS.compress_lines
            INSERT INTO #{quote_table_name(model.storage_name(name))}
            (#{properties.map { |property| quote_column_name(property.field) }.join(', ')})
            VALUES
            (#{(['?'] * properties.size).join(', ')})
          EOS
        end

        def create_statement_with_returning(model, properties)
          <<-EOS.compress_lines
            INSERT INTO #{quote_table_name(model.storage_name(name))}
            (#{properties.map { |property| quote_column_name(property.field) }.join(', ')})
            VALUES
            (#{(['?'] * properties.size).join(', ')})
            RETURNING #{quote_column_name(model.key(name).first.field)}
          EOS
        end

        def read_statement(model, key)
          properties = model.properties(name).defaults
          <<-EOS.compress_lines
            SELECT #{properties.map { |property| quote_column_name(property.field) }.join(', ')}
            FROM #{quote_table_name(model.storage_name(name))}
            WHERE #{model.key(name).map { |key| "#{quote_column_name(key.field)} = ?" }.join(' AND ')}
          EOS
        end

        def update_statement(model, properties)
          <<-EOS.compress_lines
            UPDATE #{quote_table_name(model.storage_name(name))}
            SET #{properties.map {|attribute| "#{quote_column_name(attribute.field)} = ?" }.join(', ')}
            WHERE #{model.key(name).map { |key| "#{quote_column_name(key.field)} = ?" }.join(' AND ')}
          EOS
        end

        def delete_statement(model)
          <<-EOS.compress_lines
            DELETE FROM #{quote_table_name(model.storage_name(name))}
            WHERE #{model.key(name).map { |key| "#{quote_column_name(key.field)} = ?" }.join(' AND ')}
          EOS
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
          <<-EOS.compress_lines
            DROP TABLE IF EXISTS #{quote_table_name(model.storage_name(name))}
          EOS
        end

        def property_schema_hash(property, model)
          schema = type_map[property.type].merge(:name => property.field)
          # TODO: figure out a way to specify the size not be included, even if a default is defined in the typemap
          #  - use this to make it so all TEXT primitive fields do not have size
          if property.primitive == String && schema[:primitive] != 'TEXT'
            schema[:size] = property.length
          elsif property.primitive == BigDecimal
            schema[:precision] = property.precision
            schema[:scale]     = property.scale
          end

          schema[:nullable?] = property.nullable?
          schema[:serial?]   = property.serial?
          schema[:default]   = property.default unless property.default.nil? || property.default.respond_to?(:call)

          schema
        end

        def property_schema_statement(schema)
          statement = quote_column_name(schema[:name])
          statement << " #{schema[:primitive]}"

          if schema[:precision] && schema[:scale]
            statement << "(#{schema[:precision]},#{schema[:scale]})"
          elsif schema[:size]
            statement << "(#{schema[:size]})"
          end

          statement << ' NOT NULL' unless schema[:nullable?]
          statement << " DEFAULT #{quote_column_value(schema[:default])}" if schema.has_key?(:default)
          statement
        end

        def relationship_schema_hash(relationship)
          identifier, relationship = relationship

          type_map[Fixnum].merge(:name => "#{identifier}_id") if identifier == relationship.name
        end

        def relationship_schema_statement(hash)
          property_schema_statement(hash) unless hash.nil?
        end

        def query_read_statement(query)
          qualify = query.links.any?

          sql = "SELECT "

          sql << query.fields.map do |property|
            # TODO Should we raise an error if there is no such property in the
            #      repository of the query?
            #
            #if property.model.properties(query.repository.name)[property.name].nil?
            #  raise "Property #{property.model.to_s}.#{property.name.to_s} not available in repository #{query.repository.name}."
            #end
            #
            model_name = property.model.storage_name(query.repository.name)
            property_to_column_name(model_name, property, qualify)
          end.join(', ')

          sql << " FROM " << quote_table_name(query.model_name)

          unless query.links.empty?
            joins = []
            query.links.each do |relationship|
              child_model       = relationship.child_model
              parent_model      = relationship.parent_model
              child_model_name  = child_model.storage_name(child_model.repository.name)
              parent_model_name = parent_model.storage_name(parent_model.repository.name)
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
            sql << joins.join(' ')
          end


          unless query.conditions.empty?
            sql << " WHERE "
            sql << "(" << query.conditions.map do |operator, property, value|
              # TODO Should we raise an error if there is no such property in the
              #      repository of the query?
              #
              #if property.model.properties(query.repository.name)[property.name].nil?
              #  raise "Property #{property.model.to_s}.#{property.name.to_s} not available in repository #{query.repository.name}."
              #end
              #
              model_name = property.model.storage_name(query.repository.name) if property && property.respond_to?(:model)
              case operator
                when String then operator
                when :eql, :in then equality_operator(query, model_name,operator, property, qualify, value)
                when :not      then inequality_operator(query, model_name,operator, property, qualify, value)
                when :like     then "#{property_to_column_name(model_name, property, qualify)} LIKE ?"
                when :gt       then "#{property_to_column_name(model_name, property, qualify)} > ?"
                when :gte      then "#{property_to_column_name(model_name, property, qualify)} >= ?"
                when :lt       then "#{property_to_column_name(model_name, property, qualify)} < ?"
                when :lte      then "#{property_to_column_name(model_name, property, qualify)} <= ?"
                else raise "CAN HAS CRASH?"
              end
            end.join(') AND (') << ")"
          end

          unless query.order.empty?
            parts = []
            query.order.each do |item|
              parts << item.field if DataMapper::Property === item
              parts << "#{item.property.field} #{item.direction}" if DataMapper::Query::Direction === item
            end
            sql << " ORDER BY #{parts.join(', ')}"
          end

          sql << " LIMIT #{query.limit}" if query.limit
          sql << " OFFSET #{query.offset}" if query.offset && query.offset > 0

          sql
        rescue
          DataMapper.logger.error("QUERY INVALID: #{query.inspect}")
          raise $!
        end

        def equality_operator(query, model_name, operator, property, qualify, value)
          case value
            when Array             then "#{property_to_column_name(model_name, property, qualify)} IN ?"
            when Range             then "#{property_to_column_name(model_name, property, qualify)} BETWEEN ?"
            when NilClass          then "#{property_to_column_name(model_name, property, qualify)} IS NULL"
            when DataMapper::Query then
              query.merge_sub_select_conditions(operator, property, value)
              "#{property_to_column_name(model_name, property, qualify)} IN (#{query_read_statement(value)})"
            else "#{property_to_column_name(model_name, property, qualify)} = ?"
          end
        end

        def inequality_operator(query, model_name, operator, property, qualify, value)
          case value
            when Array             then "#{property_to_column_name(model_name, property, qualify)} NOT IN ?"
            when Range             then "#{property_to_column_name(model_name, property, qualify)} NOT BETWEEN ?"
            when NilClass          then "#{property_to_column_name(model_name, property, qualify)} IS NOT NULL"
            when DataMapper::Query then
              query.merge_sub_select_conditions(operator, property, value)
              "#{property_to_column_name(model_name, property, qualify)} NOT IN (#{query_read_statement(value)})"
            else "#{property_to_column_name(model_name, property, qualify)} <> ?"
          end
        end

        def property_to_column_name(model_name, property, qualify)
          if qualify
            quote_table_name(model_name) + '.' + quote_column_name(property.field)
          else
            quote_column_name(property.field)
          end
        end
      end #module SQL

      include SQL

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

      def empty_insert_sql
        "DEFAULT VALUES"
      end

      # Adapters requiring a RETURNING syntax for create statements
      # should overwrite this to return true.
      def syntax_returning?
        false
      end

    end # class DoAdapter
  end # module Adapters
end # module DataMapper
