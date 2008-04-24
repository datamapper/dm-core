gem 'do_sqlite3', '=0.9.0'
require 'do_sqlite3'

module DataMapper
  module Adapters

    class Sqlite3Adapter < DataObjectsAdapter

      include DataMapper::Adapters::StandardSqlTransactions

      def self.type_map
        @type_map ||= TypeMap.new(super) do |tm|
          tm.map(String).to(:VARCHAR).with(:size => 50)
          tm.map(Fixnum).to(:INTEGER)
          tm.map(Class).to(:VARCHAR).with(:size => 50)
        end
      end

      def rewrite_uri(uri, options)
        new_uri = uri.dup
        new_uri.path = options[:path] || uri.path

        new_uri
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
