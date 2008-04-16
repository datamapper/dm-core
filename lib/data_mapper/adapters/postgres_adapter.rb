require __DIR__ + 'data_objects_adapter'
require "do_postgres"

module DataMapper
  module Adapters

    class PostgresAdapter < DataObjectsAdapter
      
      TYPES = DataObjectsAdapter::TYPES.merge!({
        DateTime => 'timestamp'.freeze
      })

      def create_with_returning?; true; end
      
      def drop_table_statement(model)
        <<-EOS.compress_lines
          DROP TABLE IF EXISTS #{quote_table_name(model.storage_name(name))}
        EOS
      end

    end # class PostgresAdapter

  end # module Adapters
end # module DataMapper
