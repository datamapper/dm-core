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
        if within_transaction?
          Thread::current["doa_#{@uri.scheme}_transaction"]
        else
          # DataObjects::Connection.new(uri) will give you back the right
          # driver based on the Uri#scheme.
          DataObjects::Sqlite3::Connection.new(@uri)
        end
      end

      def rewrite_uri(uri, options)
        new_uri = uri.dup
        new_uri.path = options[:path] || uri.path

        new_uri
      end
      
      def begin_transaction
        connection = create_connection
        Thread::current["doa_#{@uri.scheme}_transaction"] = connection
        DataMapper.logger.debug("BEGIN TRANSACTION")
        command = connection.create_command("BEGIN")
        command.execute_non_query
      end

      def commit_transaction
        connection = create_connection
        Thread::current["doa_#{@uri.scheme}_transaction"] = nil
        DataMapper.logger.debug("COMMIT TRANSACTION")
        command = connection.create_command("COMMIT")
        command.execute_non_query
      end

      def rollback_transaction
        connection = create_connection
        Thread::current["doa_#{@uri.scheme}_transaction"] = nil
        DataMapper.logger.debug("ROLLBACK TRANSACTION")
        command = connection.create_command("ROLLBACK")
        command.execute_non_query
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
