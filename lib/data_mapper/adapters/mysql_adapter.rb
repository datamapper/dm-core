gem 'do_mysql', '=0.9.0'
require 'do_mysql'

module DataMapper
  module Adapters

    # Options:
    # host, user, password, database (path), socket(uri query string), port
    class MysqlAdapter < DataObjectsAdapter
      private

      def quote_table_name(table_name)
        "`#{table_name}`"
      end

      def quote_column_name(column_name)
        "`#{column_name}`"
      end

      def rewrite_uri(uri, options)
        new_uri = uri.dup
        new_uri.host = options[:host] || uri.host
        new_uri.user = options[:user] || uri.user
        new_uri.password = options[:password] || uri.password
        new_uri.path = (options[:database] && "/" << options[:database]) || uri.path
        new_uri.port = options[:port] || uri.port
        new_uri.query = (options[:socket] && "socket=#{options[:socket]}") || uri.query

        new_uri
      end

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

    end # class MysqlAdapter
  end # module Adapters
end # module DataMapper
