require __DIR__ + 'data_objects_adapter'
require 'do_sqlite3'

module DataMapper
  module Adapters
    
    class Sqlite3Adapter < DataObjectsAdapter
      
      TYPES.merge!({
	  :integer => 'INTEGER'.freeze,
	  :string  => 'TEXT'.freeze,
	  :text    => 'TEXT'.freeze,
	  :class   => 'TEXT'.freeze,
	  :boolean => 'INTEGER'.freeze
	})

      def create_connection
        connnection = DataObjects::Sqlite3::Connection.new(@uri)
        # connnection.logger = DataMapper.logger
        return connnection
      end

      def uri(uri_or_options)
	uri = super(uri_or_options)
	uri.path = File.join(Dir.pwd, File.dirname(uri.path), File.basename(uri.path)) unless File.exists?(uri.path)
	uri
      end
    end # class Sqlite3Adapter
    
  end # module Adapters
end # module DataMapper
