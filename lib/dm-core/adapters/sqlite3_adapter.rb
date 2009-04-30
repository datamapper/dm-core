require DataMapper.root / 'lib' / 'dm-core' / 'adapters' / 'data_objects_adapter'

gem 'do_sqlite3', '~>0.9.12'
require 'do_sqlite3'

module DataMapper
  module Adapters
    class Sqlite3Adapter < DataObjectsAdapter
    end # class Sqlite3Adapter

    const_added(:Sqlite3Adapter)
  end # module Adapters
end # module DataMapper
