gem 'do_postgres', '=0.9.0'
require 'do_postgres'

module DataMapper
  module Adapters

    class PostgresAdapter < DataObjectsAdapter

      # TypeMap for PostgreSQL databases.
      #
      # ==== Returns
      # DataMapper::TypeMap:: default TypeMap for PostgreSQL databases.
      def self.type_map
        @type_map ||= TypeMap.new(super) do |tm|
          tm.map(DateTime).to('TIMESTAMP')
          tm.map(Fixnum).to('INT4')
          tm.map(Float).to('FLOAT8')
        end
      end

      def table_exists?(table_name)
        query_table(table_name).size > 0
      end

      def db_name
        @uri.path.split('/').last
      end

      def query_table(table_name)
        query("SELECT * FROM information_schema.columns WHERE table_name='#{table_name}' AND table_schema=current_schema()")
      end

      def begin_transaction(transaction)
        cmd = "BEGIN"
        transaction.connection_for(self).create_command(cmd).execute_non_query
        DataMapper.logger.debug("#{self}: #{cmd}")
      end

      def transaction_id(transaction)
        "#{transaction.id}:#{self.object_id}"
      end

      def commit_transaction(transaction)
        cmd = "COMMIT PREPARED '#{transaction_id(transaction)}'"
        transaction.connection_for(self).create_command(cmd).execute_non_query
        DataMapper.logger.debug("#{self}: #{cmd}")
      end

      def prepare_transaction(transaction)
        cmd = "PREPARE TRANSACTION '#{transaction_id(transaction)}'"
        transaction.connection_for(self).create_command(cmd).execute_non_query
        DataMapper.logger.debug("#{self}: #{cmd}")
      end

      def rollback_transaction(transaction)
        cmd = "ROLLBACK"
        transaction.connection_for(self).create_command(cmd).execute_non_query
        DataMapper.logger.debug("#{self}: #{cmd}")
      end

      def rollback_prepared_transaction(transaction)
        cmd = "ROLLBACK PREPARED '#{transaction_id(transaction)}'"
        transaction.connection.create_command(cmd).execute_non_query
        DataMapper.logger.debug("#{self}: #{cmd}")
      end

      def create_with_returning?; true; end

      def column_exists?(table_name, column_name)
        query("SELECT pg_attribute.attname 
               FROM pg_class JOIN pg_attribute ON pg_class.oid = pg_attribute.attrelid
               WHERE pg_attribute.attname = ? AND 
               pg_class.relname = ? AND pg_attribute.attnum >= 0", column_name, table_name).size > 0
      end

      def upgrade_model_storage(repository, model)
        table_name = model.storage_name(name)
        with_connection do |connection|
          model.properties.each do |property|
            schema_hash = property_schema_hash(property, model)
            create_sequence_column(connection, model, property) if property.serial? && !column_exists?(table_name, schema_hash[:name])
          end
        end
        super
      end

      def create_model_storage(repository, model)
        with_connection do |connection|
          model.properties.each do |property|
            create_sequence_column(connection, model, property) if property.serial?
          end
        end
        super
      end

      def destroy_model_storage(repository, model)
        rval = super
        with_connection do |connection|
          model.properties.each do |property|
            drop_sequence_column(connection, model, property) if property.serial?
          end
        end
        rval
      end

      def create_sequence_column(connection, model, property)
        sql = create_sequence_statement(model, property)

        DataMapper.logger.debug "CREATE SEQUENCE: #{sql}"

        command = connection.create_command(sql)

        command.execute_non_query
      end

      def create_sequence_statement(model, property)
        statement = "CREATE SEQUENCE "
        statement << quote_column_name(sequence_name(model, property))
        statement
      end

      def drop_sequence_column(connection, model, property)
        DataMapper.logger.debug "DROP SEQUENCE: #{model.storage_name(name)}_#{property.field}_seq"

        command = connection.create_command(drop_sequence_statement(model, property))

        command.execute_non_query
      end

      def drop_sequence_statement(model, property)
        statement = "DROP SEQUENCE IF EXISTS "
        statement << quote_column_name(sequence_name(model, property))
        statement
      end

      def create_with_returning?; true; end

      private

      def sequence_name(model, property)
        "#{model.storage_name(name)}_#{property.field}_seq"
      end

      def property_schema_statement(schema)
        statement = super

        if schema.has_key?(:sequence_name)
          statement << ' DEFAULT nextval('
          statement << "'#{schema[:sequence_name]}'"  #not sure why this has to be single quotes
          statement << ') NOT NULL'
        end

        statement
      end

      def property_schema_hash(property, model)
        schema = super
        schema[:sequence_name] = sequence_name(model, property) if property.serial?

        # TODO: see if TypeMap can be updated to set specific attributes to nil
        # for different adapters.  scale/precision are perfect examples for
        # Postgres floats

        # Postgres does not support scale and precision for Float
        if property.primitive == Float
          schema.delete(:scale)
          schema.delete(:precision)
        end

        schema
      end
    end # class PostgresAdapter

  end # module Adapters
end # module DataMapper
