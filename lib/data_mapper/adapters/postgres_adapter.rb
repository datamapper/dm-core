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
          tm.map(DateTime).to(:timestamp)
          tm.map(String).with(:size => 50)
          tm.map(Fixnum).to(:INT4)
        end
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

      def self.type_map
        @type_map ||= TypeMap.new(super) do |tm|
          tm.map(DateTime).to(:timestamp)
          tm.map(String).with(:size => 50)
          tm.map(Fixnum).to(:INT4)
        end
      end

      def create_with_returning?; true; end
      
      def create_model_storage(repository, model)
        DataMapper.logger.debug "CREATE TABLE: #{model.storage_name(name)}  COLUMNS: #{model.properties.map {|p| p.field}.join(', ')}"

        connection = create_connection
        
        model.properties.each do |property|
          create_sequence_column(connection, model, property) if sequenced?(property)
        end

        command = connection.create_command(create_table_statement(model))

        result = command.execute_non_query

        close_connection(connection)

        result.to_i == 1
      end
      
      def destroy_model_storage(repository, model)
        DataMapper.logger.debug "DROP TABLE: #{model.storage_name(name)}"

        connection = create_connection

        command = connection.create_command(drop_table_statement(model))

        result = command.execute_non_query

        model.properties.each do |property|
          drop_sequence_column(connection, model, property) if sequenced?(property)
        end

        close_connection(connection)

        result.to_i == 1
      end
      
      def sequenced?(property)
        property.serial?
      end
      
      def create_table_statement(model)
        statement = "CREATE TABLE #{quote_table_name(model.storage_name(name))} ("

        statement << model.properties.collect do |property|
          schema = property_schema_hash(property)

          if sequenced?(property)
            property_statement = quote_column_name(schema[:name])
            property_statement << " #{schema[:primitive]}"
            property_statement << "(#{schema[:size]})" if schema[:size]
            property_statement << " DEFAULT nextval("
            property_statement << "'#{model.storage_name(name)}_#{property.field}_seq'"  #not sure why this has to be single qoutes
            property_statement << ") NOT NULL"
          else
            property_statement = quote_column_name(schema[:name])
            property_statement << " #{schema[:primitive]}"
            property_statement << "(#{schema[:size]})" if schema[:size]
          end

          property_statement
        end.join(", ")

        statement << ")"

        statement
      end

      def create_sequence_column(connection, model, property)
        DataMapper.logger.debug "CREATE SEQUENCE: #{model.storage_name(name)}_#{property.field}_seq"

        command = connection.create_command(create_sequence_statement(model, property))

        command.execute_non_query
      end
      
      def create_sequence_statement(model, property)
        statement = "CREATE SEQUENCE "
        statement << quote_column_name("#{model.storage_name(name)}_#{property.field}_seq")
        statement
        
        statement
      end
      
      def drop_sequence_column(connection, model, property)
        DataMapper.logger.debug "DROP SEQUENCE: #{model.storage_name(name)}_#{property.field}_seq"
        
        command = connection.create_command(drop_sequence_statement(model, property))
        
        command.execute_non_query
      end
      
      def drop_sequence_statement(model, property)
        statement = "DROP SEQUENCE IF EXISTS "
        statement << quote_column_name("#{model.storage_name(name)}_#{property.field}_seq")
        statement
      end

      def create_with_returning?; true; end
      
    end # class PostgresAdapter

  end # module Adapters
end # module DataMapper
