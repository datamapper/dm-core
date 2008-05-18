gem 'do_sqlite3', '=0.9.0'
require 'do_sqlite3'

module DataMapper
  module Adapters

    class Sqlite3Adapter < DataObjectsAdapter

      # TypeMap for SQLite 3 databases.
      #
      # @return <DataMapper::TypeMap> default TypeMap for SQLite 3 databases.
      def self.type_map
        @type_map ||= TypeMap.new(super) do |tm|
          tm.map(Fixnum).to('INTEGER')
          tm.map(Class).to('VARCHAR')
        end
      end

      def storage_exists?(storage_name)
        query_table(storage_name).size > 0
      end
      alias exists? storage_exists?

      def field_exists?(storage_name, column_name)
        query_table(storage_name).any? do |row|
          row.name == column_name
        end
      end

      protected

      def normalize_uri(uri_or_options)
        uri = super
        uri.path = File.join(Dir.pwd, File.dirname(uri.path), File.basename(uri.path)) unless File.exists?(uri.path) or uri.path == ':memory:'
        uri
      end

      private

      def query_table(table_name)
        query('PRAGMA table_info(?)', table_name)
      end

      module SQL
        def create_table_statement(model)
          statement = "CREATE TABLE #{quote_table_name(model.storage_name(name))} ("
          statement << "#{model.properties.collect {|p| property_schema_statement(property_schema_hash(p, model)) } * ', '}"

          # skip adding the primary key if one of the columns is serial.  In
          # SQLite the serial column must be the primary key, so it has already
          # been defined
          unless model.properties.any? { |p| p.serial? }
            if (key = model.properties.key).any?
              statement << ", PRIMARY KEY(#{ key.collect { |p| quote_column_name(p.field) } * ', '})"
            end
          end

          statement << ')'
          statement.compress_lines
        end

        def property_schema_statement(schema)
          statement = super
          statement << ' PRIMARY KEY AUTOINCREMENT' if schema[:serial?] && supports_autoincrement?
          statement
        end

        def quote_column_value(column_value)
          case column_value
            when TrueClass  then quote_column_value('t')
            when FalseClass then quote_column_value('f')
            else
              super
          end
        end

        def supports_autoincrement?
          sqlite_version >= '3.1.0'
        end

        def sqlite_version
          @sqlite_version ||= query('SELECT sqlite_version(*)').first
        end
      end

      include SQL
    end # class Sqlite3Adapter

  end # module Adapters
end # module DataMapper
