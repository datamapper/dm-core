require __DIR__ + 'data_objects_adapter'
require 'do_sqlite3'

module DataMapper
  module Adapters
    
    class Sqlite3Adapter < DataObjectsAdapter
      
      def self.type_map=(value)
        @type_map = value
      end
      
      def self.type_map
        @type_map ||= {}
      end
      
      self.type_map = DataObjectsAdapter.type_map
      
      #map_types({
      #  Fixnum                  => 'INTEGER'.freeze,
      #  String                  => 'TEXT'.freeze,
      #  DataMapper::Types::Text => 'TEXT'.freeze,
      #  Class                   => 'TEXT'.freeze,
      #  TrueClass               => 'INTEGER'.freeze
      #})

      def create_connection
        connnection = DataObjects::Sqlite3::Connection.new(@uri)
        # connnection.logger = DataMapper.logger
        return connnection
      end

      protected

      def normalize_uri(uri_or_options)
        uri = super(uri_or_options)
        uri.path = File.join(Dir.pwd, File.dirname(uri.path), File.basename(uri.path)) unless File.exists?(uri.path)
        uri
      end
    end # class Sqlite3Adapter

  end # module Adapters
end # module DataMapper
