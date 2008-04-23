require __DIR__ + 'data_objects_adapter'
require 'do_sqlite3'

module DataMapper
  module Adapters

    class Sqlite3Adapter < DataObjectsAdapter

      def self.type_map
        @type_map ||= TypeMap.new(super) do |tm|
          tm.map(String).to(:VARCHAR).with(:size => 50)
          tm.map(Fixnum).to(:INTEGER)
          tm.map(Class).to(:VARCHAR).with(:size => 50)
        end
      end

      def create_connection
        DataObjects::Sqlite3::Connection.new(@uri)
      end

      protected

      def normalize_uri(uri_or_options)
        uri = super
        uri.path = File.join(Dir.pwd, File.dirname(uri.path), File.basename(uri.path)) unless File.exists?(uri.path)
        uri
      end
    end # class Sqlite3Adapter

  end # module Adapters
end # module DataMapper
