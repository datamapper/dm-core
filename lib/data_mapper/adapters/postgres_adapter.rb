gem 'do_postgres', '=0.9.0'
require 'do_postgres'

module DataMapper
  module Adapters

    class PostgresAdapter < DataObjectsAdapter

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
      
    end # class PostgresAdapter

  end # module Adapters
end # module DataMapper
