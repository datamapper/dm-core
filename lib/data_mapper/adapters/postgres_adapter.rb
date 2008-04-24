gem 'do_postgres', '=0.9.0'
require 'do_postgres'

module DataMapper
  module Adapters

    class PostgresAdapter < DataObjectsAdapter

      def create_with_returning?; true; end
      
      def begin_transaction
        connection = create_connection
        Thread::current["doa_#{@uri.scheme}_transaction"] = connection
        DataMapper.logger.debug("BEGIN TRANSACTION")
        command = connection.create_command("BEGIN")
        command.execute_non_query
      end

      def commit_transaction
        connection = create_connection
        Thread::current["doa_#{@uri.scheme}_transaction"] = nil
        DataMapper.logger.debug("COMMIT TRANSACTION")
        command = connection.create_command("COMMIT")
        command.execute_non_query
      end

      def rollback_transaction
        connection = create_connection
        Thread::current["doa_#{@uri.scheme}_transaction"] = nil
        DataMapper.logger.debug("ROLLBACK TRANSACTION")
        command = connection.create_command("ROLLBACK")
        command.execute_non_query
      end

    end # class PostgresAdapter

  end # module Adapters
end # module DataMapper
