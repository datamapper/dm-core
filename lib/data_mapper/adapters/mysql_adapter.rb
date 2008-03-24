require __DIR__ + 'data_objects_adapter'
require 'rbmysql'

module DataMapper
  module Adapters
    
    class MysqlAdapter < DataObjectsAdapter
      
      def quote_table_name(table_name)
        table_name.ensure_wrapped_with('`')
      end

      def quote_column_name(column_name)
        column_name.ensure_wrapped_with('`')
      end
      
    end # class MysqlAdapter
    
  end # module Adapters
end # module DataMapper
