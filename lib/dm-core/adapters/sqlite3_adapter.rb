gem 'do_sqlite3', '=0.9.1'
require 'do_sqlite3'

module DataMapper
  module Adapters

    class Sqlite3Adapter < DataObjectsAdapter

      # TypeMap for SQLite 3 databases.
      #
      # @return <DataMapper::TypeMap> default TypeMap for SQLite 3 databases.
      def self.type_map
        @type_map ||= TypeMap.new(super) do |tm|
          tm.map(Integer).to('INTEGER')
          tm.map(Class).to('VARCHAR')
        end
      end

      # TODO: move to dm-more/dm-migrations (if possible)
      def storage_exists?(storage_name)
        query_table(storage_name).size > 0
      end

      # TODO: remove this alias
      alias exists? storage_exists?

      # TODO: move to dm-more/dm-migrations (if possible)
      def field_exists?(storage_name, column_name)
        query_table(storage_name).any? do |row|
          row.name == column_name
        end
      end

      protected

      def normalize_uri(uri_or_options)
        uri = super
        uri.path = File.expand_path(uri.path) unless uri.path == ':memory:'
        uri
      end

      private

      # TODO: move to dm-more/dm-migrations (if possible)
      def query_table(table_name)
        query('PRAGMA table_info(?)', table_name)
      end

      module SQL
        private

        def quote_column_value(column_value)
          case column_value
            when TrueClass  then quote_column_value('t')
            when FalseClass then quote_column_value('f')
            else
              super
          end
        end

        # TODO: move to dm-more/dm-migrations
        def supports_serial?
          sqlite_version >= '3.1.0'
        end

        # TODO: move to dm-more/dm-migrations
        def create_table_statement(model)
          statement = "CREATE TABLE #{quote_table_name(model.storage_name(name))} ("
          statement << "#{model.properties.collect {|p| property_schema_statement(property_schema_hash(p, model)) } * ', '}"

          # skip adding the primary key if one of the columns is serial.  In
          # SQLite the serial column must be the primary key, so it has already
          # been defined
          unless model.properties.any? { |p| p.serial? }
            if (key = model.properties.key).any?
              statement << ", PRIMARY KEY(#{ key.collect { |p| quote_column_name(p.field(name)) } * ', '})"
            end
          end

          statement << ')'
          statement.compress_lines
        end

        # TODO: move to dm-more/dm-migrations
        def property_schema_statement(schema)
          statement = super
          statement << ' PRIMARY KEY AUTOINCREMENT' if supports_serial? && schema[:serial?]
          statement
        end

        # TODO: move to dm-more/dm-migrations
        def sqlite_version
          @sqlite_version ||= query('SELECT sqlite_version(*)').first
        end
      end

      include SQL
    end # class Sqlite3Adapter

  end # module Adapters
end # module DataMapper
