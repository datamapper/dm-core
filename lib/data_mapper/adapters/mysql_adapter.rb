require __DIR__ + 'data_objects_adapter'
# Broke?
# gem 'do_mysql', '>= 0.9.0'
require 'do_mysql'

module DataMapper
  module Adapters

    # Options:
    # host, user, password, database (path), socket(uri query string), port
    class MysqlAdapter < DataObjectsAdapter
      
      def self.type_map
        @type_map ||= TypeMap.new(super) do |tm|
          tm.map(String).with(:size => 100)
          tm.map(DM::Text).to(:text)
          tm.map(Class).with(:size => 100)
        end
      end
      
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
