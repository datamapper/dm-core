gem 'do_postgres', '~>0.9.10'
require 'do_postgres'

module DataMapper
  module Adapters
    class PostgresAdapter < DataObjectsAdapter
      module SQL
        private

        def supports_returning?
          true
        end
      end #module SQL

      include SQL
    end # class PostgresAdapter
  end # module Adapters
end # module DataMapper
