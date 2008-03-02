require File.join(File.dirname(__FILE__), 'abstract_adapter')
require File.join(File.dirname(__FILE__), 'sql', 'commands', 'load_command')
require File.join(File.dirname(__FILE__), 'sql', 'coersion')
require File.join(File.dirname(__FILE__), 'sql', 'quoting')
require File.join(File.dirname(__FILE__), '..', 'query')

module DataMapper

  # An Adapter is really a Factory for three types of object,
  # so they can be selectively sub-classed where needed.
  #
  # The first type is a Query. The Query is an object describing
  # the database-specific operations we wish to perform, in an
  # abstract manner. For example: While most if not all databases
  # support a mechanism for limiting the size of results returned,
  # some use a "LIMIT" keyword, while others use a "TOP" keyword.
  # We can set a SelectStatement#limit field then, and allow
  # the adapter to override the underlying SQL generated.
  # Refer to DataMapper::Queries.
  #
  # The final type provided is a DataMapper::Transaction.
  # Transactions are duck-typed Connections that span multiple queries.
  #
  # Note: It is assumed that the Adapter implements it's own
  # ConnectionPool if any since some libraries implement their own at
  # a low-level, and it wouldn't make sense to pay a performance
  # cost twice by implementing a secondary pool in the DataMapper itself.
  # If the library being adapted does not provide such functionality,
  # DataMapper::Support::ConnectionPool can be used.
  module Adapters

    # You must inherit from the DoAdapter, and implement the
    # required methods to adapt a database library for use with the DataMapper.
    #
    # NOTE: By inheriting from DoAdapter, you get a copy of all the
    # standard sub-modules (Quoting, Coersion and Queries) in your own Adapter.
    # You can extend and overwrite these copies without affecting the originals.
    class DataObjectAdapter < AbstractAdapter

      TYPES = {
        :integer => 'int'.freeze,
        :string => 'varchar'.freeze,
        :text => 'text'.freeze,
        :class => 'varchar'.freeze,
        :decimal => 'decimal'.freeze,
        :float => 'float'.freeze,
        :datetime => 'datetime'.freeze,
        :date => 'date'.freeze,
        :boolean => 'boolean'.freeze,
        :object => 'text'.freeze
      }

      include Sql
      include Quoting
      include Coersion
      
      FIND_OPTIONS = [
        :select, :offset, :limit, :class, :include, :shallow_include, :reload, :conditions, :order, :intercept_load
      ]

      TABLE_QUOTING_CHARACTER = '`'.freeze
      COLUMN_QUOTING_CHARACTER = '`'.freeze

      SYNTAX = {
        :now => 'NOW()'.freeze
      }

      def activated?
        @activated
      end

      def activate!
        @activated = true
        schema.activate!
      end

      def create_connection
        raise NotImplementedError.new
      end

      def batch_insertable?
        true
      end

      # Yields an available connection. Flushes the connection-pool and reconnects
      # if the connection returns an error.
      def connection
        begin
          # Yield the appropriate connection
          @connection_pool.hold { |active_connection| yield(active_connection) }
        rescue => execution_error
          # Log error on failure
          logger.error { execution_error }

          # Close all open connections, assuming that if one
          # had an error, it's likely due to a lost connection,
          # in which case all connections are likely broken.
          flush_connections!

          raise execution_error
        end
      end

      # Close any open connections.
      def flush_connections!
        begin
          @connection_pool.available_connections.each do |active_connection|
            active_connection.close
          end
        rescue => close_connection_error
          # An error on closing the connection is almost expected
          # if the socket is broken.
          logger.warn { close_connection_error }
        end

        # Reopen fresh connections.
        @connection_pool.available_connections.clear
      end

      def transaction(&block)
        raise NotImplementedError.new
      end

      def query(*args)
        db = create_connection

        command = db.create_command(args.shift)

        reader = command.execute_reader(*args)
        fields = reader.fields.map { |field| Inflector.underscore(field).to_sym }
        results = []

        if fields.size > 1
          struct = Struct.new(*fields)

          reader.each do
            results << struct.new(*reader.current_row)
          end
        else
          reader.each do
            results << reader.item(0)
          end
        end

        return results
      rescue => e
        logger.error { e }
        raise e
      ensure
        reader.close if reader
        db.close
      end

      def execute(*args)
        db = create_connection
        command = db.create_command(args.shift)
        return command.execute_non_query(*args)
      rescue => e
        logger.error { e }
        raise e
      ensure
        db.close
      end

      def handle_error(error)
        raise error
      end

      def column_exists_for_table?(table_name, column_name)
        connection do |db|
          table = self.table(table_name)
          command = db.create_command(table.to_column_exists_sql)
          command.execute_reader(table.name, column_name, table.schema.name) do |reader|
            reader.any? { reader.item(1) == column_name.to_s }
          end
        end
      end

      def delete(database_context, instance)
        table = self.table(instance)

        if instance.is_a?(Class)
          table.delete_all!
        else
          callback(instance, :before_destroy)

          table.associations.each do |association|
            instance.send(association.name).deactivate unless association.is_a?(::DataMapper::Associations::BelongsToAssociation)
          end

          if table.paranoid?
            instance.instance_variable_set(table.paranoid_column.instance_variable_name, Time::now)
            instance.save
          else
            if connection do |db|
                command = db.create_command("DELETE FROM #{table.to_sql} WHERE #{table.key.to_sql} = ?")
                command.execute_non_query(instance.key).to_i > 0
              end # connection do...end # if continued below:
              instance.instance_variable_set(:@new_record, true)
              instance.database_context = database_context
              instance.original_values.clear
              database_context.identity_map.delete(instance)
              callback(instance, :after_destroy)
            end
          end
        end
      end

      def save(database_context, instance, validate = true, cleared = Set.new)
        case instance
        when Class then
          table(instance).create!
          table(instance).activate_associations!
        when Mappings::Table then instance.create!
        when DataMapper::Persistable then
          event = instance.new_record? ? :create : :update

          return false if (validate && !instance.validate_recursively(event, Set.new)) || cleared.include?(instance)
          cleared << instance

          callback(instance, :before_save)

          return true unless instance.new_record? || instance.dirty?

          result = send(event, database_context, instance)

          instance.database_context = database_context
          instance.attributes.each_pair do |name, value|
            instance.original_values[name] = value
          end

          instance.loaded_associations.each do |association|
            association.save_without_validation(database_context, cleared) if association.dirty?
          end

          callback(instance, :after_save)
          result
        end
      rescue => error
        logger.error(error)
        raise error
      end

      def save_without_validation(database_context, instance, cleared = Set.new)
        save(database_context, instance, false, cleared)
      end

      def update(database_context, instance)
        callback(instance, :before_update)

        instance = update_magic_properties(database_context, instance)

        table = self.table(instance)
        attributes = instance.dirty_attributes
        parameters = []

        unless attributes.empty?
          sql = "UPDATE " << table.to_sql << " SET "

          sql << attributes.map do |key, value|
            parameters << value
            "#{table[key].to_sql} = ?"
          end.join(', ')

          sql << " WHERE #{table.key.to_sql} = ?"
          parameters << instance.key

          result = connection do |db|
            db.create_command(sql).execute_non_query(*parameters)
          end

          # BUG: do_mysql returns inaccurate affected row counts for UPDATE statements.
          if true || result.to_i > 0
            callback(instance, :after_update)
            return true
          else
            return false
          end
        else
          true
        end
      end

      def empty_insert_sql
        "DEFAULT VALUES"
      end

      def create(database_context, instance)
        callback(instance, :before_create)

        instance = update_magic_properties(database_context, instance)

        table = self.table(instance)
        attributes = instance.dirty_attributes

        if table.multi_class?
          instance.instance_variable_set(
            table[:type].instance_variable_name,
            attributes[:type] = instance.class.name
          )
        end

        keys = []
        values = []
        attributes.each_pair do |key, value|
          raise ArgumentError.new("#{value.inspect} is not a valid value for #{key.inspect}") if value.is_a?(Array)

          keys << table[key].to_sql
          values << value
        end

        sql = if keys.size > 0
          "INSERT INTO #{table.to_sql} (#{keys.join(', ')}) VALUES ?"
        else
          "INSERT INTO #{table.to_sql} #{self.empty_insert_sql}"
        end

        result = connection do |db|
          db.create_command(sql).execute_non_query(values)
        end

        if result.to_i > 0
          instance.instance_variable_set(:@new_record, false)
          instance.key = result.last_insert_row if table.key.serial? && !attributes.include?(table.key.name)
          database_context.identity_map.set(instance)
          callback(instance, :after_create)
          return true
        else
          return false
        end
      end

      MAGIC_PROPERTIES = {
        :updated_at => lambda { self.updated_at = Time::now },
        :updated_on => lambda { self.updated_on = Date::today },
        :created_at => lambda { self.created_at ||= Time::now },
        :created_on => lambda { self.created_on ||= Date::today }
      }

      def update_magic_properties(database_context, instance)
        instance.class.properties.find_all { |property| MAGIC_PROPERTIES.has_key?(property.name) }.each do |property|
          instance.instance_eval(&MAGIC_PROPERTIES[property.name])
        end
        instance
      end

      def load(database_context, klass, options)
        self.class::Commands::LoadCommand.new(self, database_context, klass, options).call
      end

      def get(database_context, klass, keys)
        table = self.table(klass)
        instance_id = table.key.type_cast_value(keys.first)
        instance = database_context.identity_map.get(klass, instance_id)

        return instance if instance

        column_indexes = {}
        select_columns = []

        table.columns.each_with_index do |column, i|
          column_indexes[column] = i
          select_columns << column.to_sql
        end

        sql = "SELECT #{select_columns.join(', ')} FROM #{table.to_sql} WHERE #{table.keys.map { |key| "#{key.to_sql} = ?" }.join(' AND ')}"

        connection do |db|
          reader = nil
          begin
            reader = db.create_command(sql).execute_reader(*keys)

            if reader.has_rows?

              instance_type = klass

              if table.multi_class? && table.type_column
                value = reader.item(column_indexes[table.type_column])
                instance_type = table.type_column.type_cast_value(value) unless value.blank?
              end

              if instance.nil?
                instance = instance_type.allocate()
                instance.instance_variable_set(:@__key, instance_id)
                instance.instance_variable_set(:@new_record, false)
                database_context.identity_map.set(instance)
              elsif instance.new_record?
                instance.instance_variable_set(:@__key, instance_id)
                instance.instance_variable_set(:@new_record, false)
                database_context.identity_map.set(instance)
              end

              instance.database_context = database_context

              instance_type.callbacks.execute(:before_materialize, instance)

              originals = instance.original_values

              column_indexes.each_pair do |column, i|
                value = column.type_cast_value(reader.item(i))
                instance.instance_variable_set(column.instance_variable_name, value)

                case value
                  when String, Date, Time then originals[column.name] = value.dup
                  else originals[column.name] = value
                end
              end

              instance.loaded_set = [instance]

              instance_type.callbacks.execute(:after_materialize, instance)
            end # if reader.has_rows?
          ensure
            reader.close if reader && reader.open?
          end
        end # connection

        return instance
      end

      def table(instance)
        case instance
        when DataMapper::Adapters::Sql::Mappings::Table then instance
        when DataMapper::Persistable then schema[instance.class]
        when Class, String then schema[instance]
        else raise "Don't know how to map #{instance.inspect} to a table."
        end
      end

      def callback(instance, callback_name)
        instance.class.callbacks.execute(callback_name, instance)
      end

      # This callback copies and sub-classes modules and classes
      # in the DoAdapter to the inherited class so you don't
      # have to copy and paste large blocks of code from the
      # DoAdapter.
      #
      # Basically, when inheriting from the DoAdapter, you
      # aren't just inheriting a single class, you're inheriting
      # a whole graph of Types. For convenience.
      def self.inherited(base)

        commands = base.const_set('Commands', Module.new)

        Sql::Commands.constants.each do |name|
          commands.const_set(name, Class.new(Sql::Commands.const_get(name)))
        end

        base.const_set('TYPES', TYPES.dup)
        base.const_set('FIND_OPTIONS', FIND_OPTIONS.dup)
        base.const_set('SYNTAX', SYNTAX.dup)

        super
      end

    end # class DoAdapter

  end # module Adapters
end # module DataMapper
