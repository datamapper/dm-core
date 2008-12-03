gem 'do_mysql', '~>0.9.9'
require 'do_mysql'

module DataMapper
  module Adapters
    # Options:
    # host, user, password, database (path), socket(uri query string), port
    class MysqlAdapter < DataObjectsAdapter
      module SQL
        private

        def supports_default_values?
          false
        end

        def escape_name(name)
          name.gsub('`', '``')
        end

        def quote_name(name)
          escape_name(name).split('.').map { |part| "`#{part}`" }.join('.')
        end

        # TODO: once the driver's quoting methods become public, have
        # this method delegate to them instead
        alias quote_table_name quote_name

        # TODO: once the driver's quoting methods become public, have
        # this method delegate to them instead
        alias quote_column_name quote_name

        def quote_column_value(column_value)
          case column_value
            when TrueClass  then quote_column_value(1)
            when FalseClass then quote_column_value(0)
            else
              super
          end
        end
      end #module SQL

      include SQL

      # TODO: move to dm-more/dm-migrations
      module Migration
        # TODO: move to dm-more/dm-migrations (if possible)
        def storage_exists?(storage_name)
          query('SHOW TABLES LIKE ?', storage_name).first == storage_name
        end

        # TODO: move to dm-more/dm-migrations (if possible)
        def field_exists?(storage_name, field_name)
          return false unless storage_exists?(storage_name)
          result = query("SHOW COLUMNS FROM #{quote_table_name(storage_name)} LIKE ?", field_name).first
          result ? result.field == field_name : false
        end

        private

        # TODO: move to dm-more/dm-migrations (not necessary in dm-core any longer)
        def db_name
          @uri.path.split('/').last
        end

        module SQL
          private

          # TODO: move to dm-more/dm-migrations
          def supports_serial?
            true
          end

          # TODO: move to dm-more/dm-migrations
          def create_table_statement(repository, model, properties)
            "#{super} ENGINE = InnoDB CHARACTER SET #{character_set} COLLATE #{collation}"
          end

          # TODO: move to dm-more/dm-migrations
          def property_schema_hash(property, model)
            schema = super
            schema.delete(:default) if schema[:primitive] == 'TEXT'
            schema
          end

          # TODO: move to dm-more/dm-migrations
          def property_schema_statement(schema)
            statement = super
            statement << ' AUTO_INCREMENT' if supports_serial? && schema[:serial?]
            statement
          end

          # TODO: move to dm-more/dm-migrations
          def character_set
            @character_set ||= show_variable('character_set_connection') || 'utf8'
          end

          # TODO: move to dm-more/dm-migrations
          def collation
            @collation ||= show_variable('collation_connection') || 'utf8_general_ci'
          end

          # TODO: move to dm-more/dm-migrations
          def show_variable(name)
            result = query('SHOW VARIABLES LIKE ?', name).first
            result ? result.value : nil
          end
        end # module SQL

        include SQL

        module ClassMethods
          # TypeMap for MySql databases.
          #
          # @return <DataMapper::TypeMap> default TypeMap for MySql databases.
          #
          # TODO: move to dm-more/dm-migrations
          def type_map
            @type_map ||= TypeMap.new(super) do |tm|
              tm.map(Integer).to('INT').with(:size => 11)
              tm.map(TrueClass).to('TINYINT').with(:size => 1)  # TODO: map this to a BIT or CHAR(0) field?
              tm.map(Object).to('TEXT')
            end
          end
        end # module ClassMethods
      end # module Migration

      include Migration
      extend Migration::ClassMethods
    end # class MysqlAdapter
  end # module Adapters
end # module DataMapper
