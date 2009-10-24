require DataMapper.root / 'lib' / 'dm-core' / 'adapters' / 'data_objects_adapter'

require 'do_postgres'

module DataMapper
  module Adapters
    class PostgresAdapter < DataObjectsAdapter
      module SQL #:nodoc:
        private

        # @api private
        def supports_returning?
          true
        end
      end #module SQL

      include SQL
    end # class PostgresAdapter

    const_added(:PostgresAdapter)
  end # module Adapters
end # module DataMapper
