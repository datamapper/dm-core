require __DIR__ + 'data_objects_adapter'
require 'rbmysql'

module DataMapper
  module Adapters

    # Options:
    # host, user, password, database (path), socket(uri query string), port
    class MysqlAdapter < DataObjectsAdapter

      def quote_table_name(table_name)
        table_name.ensure_wrapped_with('`')
      end

      def quote_column_name(column_name)
        column_name.ensure_wrapped_with('`')
      end


      def rewrite_uri(uri, options)
        new_uri = uri.dup
        new_uri.host = options[:host] || uri.host
        new_uri.user = options[:user] || uri.user
        new_uri.password = options[:password] || uri.password
        new_uri.path = options[:database] || uri.path
        new_uri.port = options[:port] || uri.port
        new_uri.query = (options[:socket] && "socket=#{options[:socket]}") || uri.query

        new_uri
      end
    end # class MysqlAdapter

  end # module Adapters
end # module DataMapper
