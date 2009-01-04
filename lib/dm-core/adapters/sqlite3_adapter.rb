gem 'do_sqlite3', '~>0.9.9'
require 'do_sqlite3'

module DataMapper
  module Adapters
    class Sqlite3Adapter < DataObjectsAdapter
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
      end # module SQL

      include SQL

      # TODO: move to dm-more/dm-migrations (if possible)
      module Migration
        # TODO: move to dm-more/dm-migrations (if possible)
        def storage_exists?(storage_name)
          query_table(storage_name).size > 0
        end

        # TODO: move to dm-more/dm-migrations (if possible)
        def field_exists?(storage_name, column_name)
          query_table(storage_name).any? do |row|
            row.name == column_name
          end
        end

        private

        # TODO: move to dm-more/dm-migrations (if possible)
        def query_table(table_name)
          query('PRAGMA table_info(?)', table_name)
        end

        module SQL
#          private  ## This cannot be private for current migrations

          # TODO: move to dm-more/dm-migrations
          def supports_serial?
            sqlite_version >= '3.1.0'
          end

          # TODO: move to dm-more/dm-migrations
          def create_table_statement(repository, model, properties)
            repository_name = repository.name

            statement = <<-SQL.compress_lines
              CREATE TABLE #{quote_table_name(model.storage_name(repository_name))}
              (#{properties.map { |p| property_schema_statement(property_schema_hash(p)) }.join(', ')}
            SQL

            # skip adding the primary key if one of the columns is serial.  In
            # SQLite the serial column must be the primary key, so it has already
            # been defined
            unless properties.any? { |p| p.serial? }
              statement << ", PRIMARY KEY(#{properties.key.map { |p| quote_column_name(p.field) }.join(', ')})"
            end

            statement << ')'
            statement
          end

          # TODO: move to dm-more/dm-migrations
          def property_schema_statement(schema)
            statement = super

            if supports_serial? && schema[:serial?]
              statement << ' PRIMARY KEY AUTOINCREMENT'
            end

            statement
          end

          # TODO: move to dm-more/dm-migrations
          def sqlite_version
            @sqlite_version ||= query('SELECT sqlite_version(*)').first
          end
        end # module SQL

        include SQL

        module ClassMethods
          # TypeMap for SQLite 3 databases.
          #
          # @return <DataMapper::TypeMap> default TypeMap for SQLite 3 databases.
          #
          # TODO: move to dm-more/dm-migrations
          def type_map
            @type_map ||= TypeMap.new(super) do |tm|
              tm.map(Integer).to('INTEGER')
              tm.map(Class).to('VARCHAR')
            end
          end
        end # module ClassMethods
      end # module Migration

      include Migration
      extend Migration::ClassMethods
    end # class Sqlite3Adapter
  end # module Adapters
end # module DataMapper
