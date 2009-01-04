gem 'do_postgres', '~>0.9.9'
require 'do_postgres'

module DataMapper
  module Adapters
    class PostgresAdapter < DataObjectsAdapter
      module SQL
        private

        def supports_returning?
          true
        end
      end #module SQL

      include SQL

      # TODO: move to dm-more/dm-migrations (if possible)
      module Migration
        # TODO: move to dm-more/dm-migrations (if possible)
        def storage_exists?(storage_name)
          statement = <<-SQL.compress_lines
            SELECT COUNT(*)
            FROM "information_schema"."tables"
            WHERE "table_schema" = current_schema()
            AND "table_name" = ?
          SQL

          query(statement, storage_name).first > 0
        end

        # TODO: move to dm-more/dm-migrations (if possible)
        def field_exists?(storage_name, column_name)
          statement = <<-SQL.compress_lines
            SELECT COUNT(*)
            FROM "pg_class"
            JOIN "pg_attribute" ON "pg_class"."oid" = "pg_attribute"."attrelid"
            WHERE "pg_attribute"."attname" = ?
            AND "pg_class"."relname" = ?
            AND "pg_attribute"."attnum" >= 0
          SQL

          query(statement, column_name, storage_name).first > 0
        end

        # TODO: move to dm-more/dm-migrations
        def upgrade_model_storage(repository, model)
          without_notices { super }
        end

        # TODO: move to dm-more/dm-migrations
        def create_model_storage(repository, model)
          without_notices { super }
        end

        # TODO: move to dm-more/dm-migrations
        def destroy_model_storage(repository, model)
          return true unless storage_exists?(model.storage_name(repository.name))
          without_notices { super }
        end

        protected

        module SQL
#          private  ## This cannot be private for current migrations

          # TODO: move to dm-more/dm-migrations
          def drop_table_statement(repository, model)
            "DROP TABLE #{quote_table_name(model.storage_name(repository.name))}"
          end

          # TODO: move to dm-more/dm-migrations
          def without_notices
            # execute the block with NOTICE messages disabled
            begin
              execute('SET client_min_messages = warning')
              yield
            ensure
              execute('RESET client_min_messages')
            end
          end

          # TODO: move to dm-more/dm-migrations
          def property_schema_hash(property)
            schema = super

            # TODO: see if TypeMap can be updated to set specific attributes to nil
            # for different adapters.  precision/scale are perfect examples for
            # Postgres floats

            # Postgres does not support precision and scale for Float
            if property.primitive == Float
              schema.delete(:precision)
              schema.delete(:scale)
            end

            if schema[:serial?]
              schema[:primitive] = 'SERIAL'
            end

            schema
          end
        end # module SQL

        include SQL

        module ClassMethods
          # TypeMap for PostgreSQL databases.
          #
          # @return <DataMapper::TypeMap> default TypeMap for PostgreSQL databases.
          #
          # TODO: move to dm-more/dm-migrations
          def type_map
            @type_map ||= TypeMap.new(super) do |tm|
              tm.map(Integer).to('INTEGER')
              tm.map(BigDecimal).to('NUMERIC').with(:precision => Property::DEFAULT_PRECISION, :scale => Property::DEFAULT_SCALE_BIGDECIMAL)
              tm.map(Float).to('DOUBLE PRECISION')
            end
          end
        end # module ClassMethods
      end # module Migration

      include Migration
      extend Migration::ClassMethods
    end # class PostgresAdapter
  end # module Adapters
end # module DataMapper
