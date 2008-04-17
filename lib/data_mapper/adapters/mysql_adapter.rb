require __DIR__ + 'data_objects_adapter'
# Broke?
# gem 'do_mysql', '>= 0.9.0'
require 'do_mysql'

module DataMapper
  module Adapters

    # Options:
    # host, user, password, database (path), socket(uri query string), port
    class MysqlAdapter < DataObjectsAdapter
      
      def self.type_map=(value)
        @type_map = value
      end
      
      def self.type_map
        @type_map ||= {}
      end
      
      self.type_map = DataObjectsAdapter.type_map.merge(String => 'varchar(100)'.freeze,
                      DataMapper::Types::Text => 'varchar(100)'.freeze,
                      Class => 'varchar(100)'.freeze)
      
      private

      def quote_table_name(table_name)
        "`#{table_name}`"
      end

      def quote_column_name(column_name)
        "`#{column_name}`"
      end
    end # class MysqlAdapter
  end # module Adapters
end # module DataMapper
