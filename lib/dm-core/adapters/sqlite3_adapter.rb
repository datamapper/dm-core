gem 'do_sqlite3', '~>0.9.10'
require 'do_sqlite3'

module DataMapper
  module Adapters
    class Sqlite3Adapter < DataObjectsAdapter
      module SQL
        private

        def quote_column_value(column_value)
          case column_value
            when TrueClass  then quote_column_value('t')
            when FalseClass then quote_column_value('f')
            else
              super
          end
        end
      end # module SQL

      include SQL
    end # class Sqlite3Adapter
  end # module Adapters
end # module DataMapper
