require DataMapper.root / 'lib' / 'dm-core' / 'adapters' / 'data_objects_adapter'

gem 'do_sqlite3', '~>0.9.12'
require 'do_sqlite3'

module DataMapper
  module Adapters
    class Sqlite3Adapter < DataObjectsAdapter
      module SQL #:nodoc:
        private

        # TODO: once the driver's quoting methods become public, have
        # this method delegate to them instead
        # TODO: document
        # @api private
        def quote_value(value)
          case value
            when TrueClass  then super('t')
            when FalseClass then super('f')
            else
              super
          end
        end
      end # module SQL

      include SQL
    end # class Sqlite3Adapter

    const_added(:Sqlite3Adapter)
  end # module Adapters
end # module DataMapper
