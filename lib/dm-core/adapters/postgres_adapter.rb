gem 'do_postgres', '~>0.9.10'
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

        # TODO: move to dm-more/dm-migrations
        def upgrade_model_storage(repository, model)
          # TODO: test to see if the without_notices wrapper is still needed
          without_notices { super }
        end

        # TODO: move to dm-more/dm-migrations
        def create_model_storage(repository, model)
          without_notices { super }
        end

        def destroy_model_storage(repository, model)
          if supports_drop_table_if_exists?
            without_notices { super }
          else
            super
          end
        end

        protected

        module SQL
#          private  ## This cannot be private for current migrations

          def supports_drop_table_if_exists?
            @supports_drop_table_if_exists ||= postgres_version >= '8.2'
          end

          def schema_name
            @schema_name ||= query('SELECT current_schema()').first
          end

          def postgres_version
            @postgres_version ||= query('SELECT version()').first.split[1]
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
