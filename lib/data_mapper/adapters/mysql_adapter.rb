require __DIR__ + 'data_objects_adapter'
require 'rbmysql'

module DataMapper
  module Adapters
    
    class MysqlAdapter < DataObjectsAdapter
      
      def create_connection
        DataObjects::Connection.new(@uri)
        # TODO: The above returns a connection from the pool built-in to DataObjects, NOT
        # a new Connection. So the URI should probably have a charset=UTF8 param by default.
        # cmd = conn.create_command("SET NAMES UTF8")
      end
      
      def quote_table_name(table_name)
        table_name.ensure_wrapped_with('`')
      end

      def quote_column_name(column_name)
        column_name.ensure_wrapped_with('`')
      end
      
    end # class MysqlAdapter
    
  end # module Adapters
end # module DataMapper
