require __DIR__ + 'data_objects_adapter'
require "do_postgres"

module DataMapper
  module Adapters

    class PostgresAdapter < DataObjectsAdapter
      
      def self.type_map=(value)
        @type_map = value
      end
      
      def self.type_map
        @type_map ||= {}
      end
      
      self.type_map = DataObjectsAdapter.type_map.merge(DateTime => 'timestamp'.freeze)

      def create_with_returning?; true; end

    end # class PostgresAdapter

  end # module Adapters
end # module DataMapper
