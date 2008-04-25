gem 'do_mysql', '=0.9.0'
require 'do_mysql'

module DataMapper
  module Adapters

    # Options:
    # host, user, password, database (path), socket(uri query string), port
    class MysqlAdapter < DataObjectsAdapter

      def begin_transaction(transaction)
        cmd = "XA START '#{transaction_id(transaction)}'"
        transaction.connection_for(self).create_command(cmd).execute_non_query
        DataMapper.logger.debug("#{self}: #{cmd}")
      end

      def transaction_id(transaction)
        "#{transaction.id}:#{self.object_id}"
      end

      def commit_transaction(transaction)
        cmd = "XA COMMIT '#{transaction_id(transaction)}'"
        transaction.connection_for(self).create_command(cmd).execute_non_query
        DataMapper.logger.debug("#{self}: #{cmd}")
      end

      def finalize_transaction(transaction)
        cmd = "XA END '#{transaction_id(transaction)}'"
        transaction.connection_for(self).create_command(cmd).execute_non_query
        DataMapper.logger.debug("#{self}: #{cmd}")
      end

      def prepare_transaction(transaction)
        finalize_transaction(transaction)
        cmd = "XA PREPARE '#{transaction_id(transaction)}'"
        transaction.connection_for(self).create_command(cmd).execute_non_query
        DataMapper.logger.debug("#{self}: #{cmd}")
      end
      
      def rollback_transaction(transaction)
        finalize_transaction(transaction)
        cmd = "XA ROLLBACK '#{transaction_id(transaction)}'"
        transaction.connection_for(self).create_command(cmd).execute_non_query
        DataMapper.logger.debug("#{self}: #{cmd}")
      end

      def rollback_prepared_transaction(transaction)
        cmd = "XA ROLLBACK '#{transaction_id(transaction)}'"
        transaction.connection.create_command(cmd).execute_non_query
        DataMapper.logger.debug("#{self}: #{cmd}")
      end

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

    end # class MysqlAdapter
  end # module Adapters
end # module DataMapper
