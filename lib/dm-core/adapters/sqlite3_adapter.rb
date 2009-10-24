require DataMapper.root / 'lib' / 'dm-core' / 'adapters' / 'data_objects_adapter'

require 'do_sqlite3'

module DataMapper
  module Adapters
    class Sqlite3Adapter < DataObjectsAdapter
      # @api private
      def supports_subquery?(query, source_key, target_key, qualify)
        # SQLite3 cannot match a subquery against more than one column
        source_key.size == 1 && target_key.size == 1
      end
    end # class Sqlite3Adapter

    const_added(:Sqlite3Adapter)
  end # module Adapters
end # module DataMapper
