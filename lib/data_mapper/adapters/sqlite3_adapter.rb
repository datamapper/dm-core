require Pathname(__FILE__).dirname + 'data_object_adapter'

begin
  require 'do_sqlite3'
rescue LoadError
  STDERR.puts <<-EOS
You must install the DataObjects::SQLite3 driver.
  gem install do_sqlite3
EOS
  exit
end

module DataMapper
  module Adapters
    
    class Sqlite3Adapter < DataObjectAdapter
      
      def constants
        super.merge({
          :column_quoting_character => %{"},
          :types => {
            :integer => 'INTEGER'.freeze,
            :string  => 'TEXT'.freeze,
            :text    => 'TEXT'.freeze,
            :class   => 'TEXT'.freeze,
            :boolean => 'INTEGER'.freeze
          },
          :batch_insertable? => false
        })
      end

      def create_connection
        connnection = DataObjects::Sqlite3::Connection.new(@uri)
        # connnection.logger = DataMapper.logger
        return connnection
      end
      
    end # class Sqlite3Adapter
    
  end # module Adapters
end # module DataMapper
