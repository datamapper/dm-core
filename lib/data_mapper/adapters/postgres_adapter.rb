require __DIR__ + 'data_objects_adapter'
require "do_postgres"

module DataMapper
  module Adapters

    class PostgresAdapter < DataObjectsAdapter

      def self.type_map
        @type_map ||= TypeMap.new(super) do |tm|
          tm.map(DateTime).to(:timestamp)
        end
      end

      def create_with_returning?; true; end

    end # class PostgresAdapter

  end # module Adapters
end # module DataMapper
