gem 'do_postgres', '=0.9.0'
require 'do_postgres'

module DataMapper
  module Adapters

    class PostgresAdapter < DataObjectsAdapter

      include DataMapper::Adapters::StandardSqlTransactions

      def create_with_returning?; true; end
      
    end # class PostgresAdapter

  end # module Adapters
end # module DataMapper
