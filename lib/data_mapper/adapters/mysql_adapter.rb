gem 'do_mysql', '=0.9.0'
require 'do_mysql'

module DataMapper
  module Adapters

    # Options:
    # host, user, password, database (path), socket(uri query string), port
    class MysqlAdapter < DataObjectsAdapter

      # TypeMap for MySql databases.
      #
      # ==== Returns
      # DataMapper::TypeMap:: default TypeMap for MySql databases.
      def self.type_map
        @type_map ||= TypeMap.new(super) do |tm|
          tm.map(String).with(:size => 100)
          tm.map(DM::Text).to(:text)
          tm.map(Class).with(:size => 100)
        end
      end

      private

      def quote_table_name(table_name)
        "`#{table_name}`"
      end

      def quote_column_name(column_name)
        "`#{column_name}`"
      end

      def rewrite_uri(uri, options)
        new_uri = uri.dup
        new_uri.host = options[:host] || uri.host
        new_uri.user = options[:user] || uri.user
        new_uri.password = options[:password] || uri.password
        new_uri.path = (options[:database] && "/" << options[:database]) || uri.path
        new_uri.port = options[:port] || uri.port
        new_uri.query = (options[:socket] && "socket=#{options[:socket]}") || uri.query

        new_uri
      end

    end # class MysqlAdapter
  end # module Adapters
end # module DataMapper
