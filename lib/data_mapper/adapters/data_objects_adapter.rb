require __DIR__ + 'abstract_adapter'
require 'fastthread'
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

      def self.inherited(target)
        target.const_set('TYPES', TYPES.dup)
      end

      TYPES = {
        Fixnum  => 'int'.freeze,
        String   => 'varchar'.freeze,
        DataMapper::Types::Text     => 'text'.freeze,
        Class    => 'varchar'.freeze,
        BigDecimal  => 'decimal'.freeze,
        Float    => 'float'.freeze,
        DateTime => 'datetime'.freeze,
        Date     => 'date'.freeze,
        TrueClass  => 'boolean'.freeze,
        Object   => 'text'.freeze
      }

      def begin_transaction
        raise NotImplementedError.new
      end

      def commit_transaction
        raise NotImplementedError.new
      end

      def rollback_transaction
        raise NotImplementedError.new
      end

      def within_transaction?
        !Thread::current["doa_#{@uri.scheme}_transaction"].nil?
      end

      def create_connection
        if within_transaction?
          Thread::current["doa_#{@uri.scheme}_transaction"]
        else
          # DataObjects::Connection.new(uri) will give you back the right
          # driver based on the Uri#scheme.
          DataObjects::Connection.new(@uri)
        end
      end

      def close_connection(connection)
        connection.close unless within_transaction?
      end

      def create_with_returning?
        false
      end

      # all of our CRUD
      # Methods dealing with a single instance object
      def create(repository, instance)
        properties = instance.dirty_attributes
        values = properties.map { |property| instance.instance_variable_get(property.instance_variable_name) }

        sql = send(create_with_returning? ? :create_statement_with_returning : :create_statement, instance.class, properties)

        DataMapper.logger.debug { "CREATE: #{sql}  PARAMETERS: #{values.inspect}" }

        connection = create_connection
        command = connection.create_command(sql)

        result = command.execute_non_query(*values)

        close_connection(connection)

        if result.to_i == 1
          key = instance.class.key(name)
          if key.size == 1 && key.first.serial?
            instance.instance_variable_set(key.first.instance_variable_name, result.insert_id)
          end
          true
        else
          false
        end
      end

      def read(repository, resource, key)
        properties = resource.properties(repository.name).defaults
        properties_with_indexes = Hash[*properties.zip((0...properties.size).to_a).flatten]

        set = LoadedSet.new(repository, resource, properties_with_indexes)

        connection = create_connection
        sql = read_statement(resource, key)
        DataMapper.logger.debug { sql }
        command = connection.create_command(sql)
        command.set_types(properties.map { |property| property.primitive })
        reader = command.execute_reader(*key)
        while(reader.next!)
          set.materialize!(reader.values)
        end

        reader.close
        close_connection(connection)

        set.first
      end

      def update(repository, instance)
        properties = instance.dirty_attributes
        values = properties.map { |property| instance.instance_variable_get(property.instance_variable_name) }

        sql = update_statement(instance.class, properties)
        parameters = (values + instance.key)

        DataMapper.logger.debug { "UPDATE: #{sql}  PARAMETERS: #{parameters.inspect}" }

        connection = create_connection
        command = connection.create_command(sql)

        affected_rows = command.execute_non_query(*parameters).to_i

        close_connection(connection)

        affected_rows == 1
      end

      def delete(repository, instance)
        connection = create_connection
        command = connection.create_command(delete_statement(instance.class))

        key = instance.class.key(name).map { |property| instance.instance_variable_get(property.instance_variable_name) }
        affected_rows = command.execute_non_query(*key).to_i

        close_connection(connection)

        affected_rows == 1
      end

      # Methods dealing with locating a single object, by keys
      def read_one(repository, query)
        read_set(repository, query).first

#        properties = query.resource.properties(repository.name).select { |property| !property.lazy? }
#        properties_with_indexes = Hash[*properties.zip((0...properties.size).to_a).flatten]
#
#        set = LoadedSet.new(repository, resource, properties_with_indexes)
#
#        connection = create_connection
#        command = connection.create_command(read_statement(resource, key))
#        command.set_types(properties.map { |property| property.type })
#        reader = command.execute_reader(*key)
#        while(reader.next!)
#          set.materialize!(reader.values)
#        end
#
#        reader.close
#        close_connection(connection)
#
#        set.first
      end

      # Methods dealing with finding stuff by some query parameters
      def read_set(repository, query)
        properties = query.fields
        properties_with_indexes = Hash[*properties.zip((0...properties.size).to_a).flatten]

        set = LoadedSet.new(repository, query.resource, properties_with_indexes)

        sql = query_read_statement(query)
        parameters = query.parameters

        DataMapper.logger.debug { "READ_SET: #{sql}  PARAMETERS: #{parameters.inspect}" }

        connection = create_connection
        begin
          command = connection.create_command(sql)
          command.set_types(properties.map { |property| property.primitive })
          reader = command.execute_reader(*parameters)

          while(reader.next!)
            set.materialize!(reader.values, query.reload?)
          end

          reader.close
        rescue StandardError => se
          p se, sql
          raise se
        ensure
          close_connection(connection)
        end

        set.entries
      end

      def delete_set(repository, query)
        raise NotImplementedError.new
      end

      # Database-specific method
      def execute(sql, *args)
        db = create_connection

        DataMapper.logger.debug { "EXECUTE: #{sql}  PARAMETERS: #{args.inspect}" }

        command = db.create_command(sql)
        return command.execute_non_query(*args)
      rescue => e
        DataMapper.logger.error { e } if DataMapper.logger
        raise e
      ensure
        db.close if db
      end

      def query(sql, *args)
        db = create_connection

        DataMapper.logger.debug { "QUERY: #{sql}  PARAMETERS: #{args.inspect}" }

        command = db.create_command(sql)

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
            results << reader.values[0]
          end
        end

        return results
      rescue => e
        DataMapper.logger.error { e } if DataMapper.logger
        raise e
      ensure
        reader.close if reader
        db.close if db
      end

      def empty_insert_sql
        "DEFAULT VALUES"
      end

      # This model is just for organization. The methods are included into the Adapter below.
      module SQL
        def create_statement(resource, properties)
          <<-EOS.compress_lines
            INSERT INTO #{quote_table_name(resource.resource_name(name))}
            (#{properties.map { |property| quote_column_name(property.field) }.join(', ')})
            VALUES
            (#{(['?'] * properties.size).join(', ')})
          EOS
        end

        def create_statement_with_returning(resource, properties)
          <<-EOS.compress_lines
            INSERT INTO #{quote_table_name(resource.resource_name(name))}
            (#{properties.map { |property| quote_column_name(property.field) }.join(', ')})
            VALUES
            (#{(['?'] * properties.size).join(', ')})
            RETURNING #{quote_column_name(resource.key(name).first.field)}
          EOS
        end

        def read_statement(resource, key)
          properties = resource.properties(name).defaults
          <<-EOS.compress_lines
            SELECT #{properties.map { |property| quote_column_name(property.field) }.join(', ')}
            FROM #{quote_table_name(resource.resource_name(name))}
            WHERE #{resource.key(name).map { |key| "#{quote_column_name(key.field)} = ?" }.join(' AND ')}
          EOS
        end

        def update_statement(resource, properties)
          <<-EOS.compress_lines
            UPDATE #{quote_table_name(resource.resource_name(name))}
            SET #{properties.map {|attribute| "#{quote_column_name(attribute.field)} = ?" }.join(', ')}
            WHERE #{resource.key(name).map { |key| "#{quote_column_name(key.field)} = ?" }.join(' AND ')}
          EOS
        end

        def delete_statement(resource)
          <<-EOS.compress_lines
            DELETE FROM #{quote_table_name(resource.resource_name(name))}
            WHERE #{resource.key(name).map { |key| "#{quote_column_name(key.field)} = ?" }.join(' AND ')}
          EOS
        end

        def query_read_statement(query)
          qualify = query.links.any?

          sql = "SELECT "    
          
          sql << query.fields.map do |property|
            # deriving the resource name from the property and not the query
            # allows for "foreign" properties to be qualified correctly
            resource_name = property.target.resource_name(property.target.repository.name)
            property_to_column_name(resource_name, property, qualify)
          end.join(', ')

          sql << " FROM " << quote_table_name(query.resource_name)
                
          unless query.links.empty?
            joins = []
            query.links.each do |relationship|
              child_resource = relationship.child_resource
              parent_resource = relationship.parent_resource       
              child_resource_name = child_resource.resource_name(child_resource.repository.name)
              parent_resource_name = parent_resource.resource_name(parent_resource.repository.name)
              child_keys           = relationship.child_key.to_a
              
              # We only do LEFT OUTER JOIN for now
              s = 'LEFT OUTER JOIN '              
              s << parent_resource_name << ' ON '
              parts = []
              relationship.parent_key.each_with_index do |parent_key,i|
                part = ' ('
                part <<  property_to_column_name(parent_resource_name, parent_key, true) 
                part << ' = ' 
                part <<  property_to_column_name(child_resource_name, child_keys[i], true)
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
              case operator
              when :eql, :in then equality_operator(query,operator, property, qualify, value)
              when :not then inequality_operator(query,operator, property, qualify, value)
              when :like then "#{property_to_column_name(query.resource_name, property, qualify)} LIKE ?"
              when :gt then "#{property_to_column_name(query.resource_name, property, qualify)} > ?"
              when :gte then "#{property_to_column_name(query.resource_name, property, qualify)} >= ?"
              when :lt then "#{property_to_column_name(query.resource_name, property, qualify)} < ?"
              when :lte then "#{property_to_column_name(query.resource_name, property, qualify)} <= ?"
              else raise "CAN HAS CRASH?"
              end
            end.join(') AND (') << ")"
          end

          unless query.order.empty?
            parts = []
            query.order.each do |item|
              parts << item.name if item.is_a?(DataMapper::Property)
              parts << "#{item.property.name} #{item.direction}" if item.is_a?(DataMapper::Query::Direction)
            end
            sql << " ORDER BY #{parts.join(', ')}"
          end

          sql << " LIMIT #{query.limit}" if query.limit
          sql << " OFFSET #{query.offset}" if query.offset && query.offset > 0
          
          sql
        end

        def equality_operator(query, operator, property, qualify, value)
          case value
          when Array then "#{property_to_column_name(query.resource_name, property, qualify)} IN ?"
          when NilClass then "#{property_to_column_name(query.resource_name, property, qualify)} IS NULL"
          when DataMapper::Query then
                query.merge_sub_select_conditions(operator, property, value)
              "#{property_to_column_name(query.resource_name, property, qualify)} IN (#{query_read_statement(value)})"
          else "#{property_to_column_name(query.resource_name, property, qualify)} = ?"
          end
        end

        def inequality_operator(query, operator, property, qualify, value)
          case value
          when Array then "#{property_to_column_name(query.resource_name, property, qualify)} NOT IN ?"
          when NilClass then "#{property_to_column_name(query.resource_name, property, qualify)} IS NOT NULL"
          when DataMapper::Query then
                query.merge_sub_select_conditions(operator, property, value)
              "#{property_to_column_name(query.resource_name, property, qualify)} NOT IN (#{query_read_statement(value)})"
          else "#{property_to_column_name(query.resource_name, property, qualify)} <> ?"
          end
        end

        def property_to_column_name(resource_name, property, qualify)
          if qualify
            quote_table_name(resource_name) + '.' + quote_column_name(property.field)
          else
            quote_column_name(property.field)
          end    
        end
      end #module SQL

      include SQL

      # Adapters requiring a RETURNING syntax for create statements
      # should overwrite this to return true.
      def syntax_returning?
        false
      end

      def quote_table_name(table_name)
        "\"#{table_name.gsub('"', '""')}\""
      end

      def quote_column_name(column_name)
        "\"#{column_name.gsub('"', '""')}\""
      end

    end # class DoAdapter

  end # module Adapters
end # module DataMapper
