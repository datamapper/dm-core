# TODO: move to dm-more/dm-migrations

module DataMapper
  module Migrations
    module SingletonMethods
      ##
      # destructively migrates the repository upwards to match model definitions
      #
      # @param [Symbol] name repository to act on, :default is the default
      #
      # @api public
      def migrate!(repository_name = nil)
        repository(repository_name).migrate!
      end

      ##
      # drops and recreates the repository upwards to match model definitions
      #
      # @param [Symbol] name repository to act on, :default is the default
      #
      # @api public
      def auto_migrate!(repository_name = nil)
        auto_migrate_down!(repository_name)
        auto_migrate_up!(repository_name)
      end

      # TODO: document
      # @api public
      def auto_upgrade!(repository_name = nil)
        repository_execute(:auto_upgrade!, repository_name)
      end

      private

      # TODO: document
      # @api private
      def auto_migrate_down!(repository_name)
        repository_execute(:auto_migrate_down!, repository_name)
      end

      # TODO: document
      # @api private
      def auto_migrate_up!(repository_name)
        repository_execute(:auto_migrate_up!, repository_name)
      end

      # TODO: document
      # @api private
      def repository_execute(method, repository_name)
        DataMapper::Model.descendants.each do |model|
          model.send(method, repository_name || model.default_repository_name)
        end
      end
    end

    module DataObjectsAdapter
      # TODO: document
      # @api private
      def self.included(base)
        base.extend ClassMethods

        DataMapper.extend(Migrations::SingletonMethods)

        [ :Repository, :Model ].each do |name|
          DataMapper.const_get(name).send(:include, Migrations.const_get(name))
        end
      end

      ##
      # Returns whether the storage_name exists.
      #
      # @param [String] storage_name
      #   a String defining the name of a storage, for example a table name.
      #
      # @return [TrueClass, FalseClass]
      #   true if the storage exists
      #
      # @api semipublic
      def storage_exists?(storage_name)
        statement = <<-SQL.compress_lines
          SELECT COUNT(*)
          FROM "information_schema"."tables"
          WHERE "table_type" = 'BASE TABLE'
          AND "table_schema" = ?
          AND "table_name" = ?
        SQL

        query(statement, schema_name, storage_name).first > 0
      end

      ##
      # Returns whether the field exists.
      #
      # @param [String] storage_name
      #   a String defining the name of a storage, for example a table name.
      # @param [String] field
      #   a String defining the name of a field, for example a column name.
      #
      # @return [TrueClass, FalseClass]
      #   true if the field exists.
      #
      # @api semipublic
      def field_exists?(storage_name, column_name)
        statement = <<-SQL.compress_lines
          SELECT COUNT(*)
          FROM "information_schema"."columns"
          WHERE "table_schema" = ?
          AND "table_name" = ?
          AND "column_name" = ?
        SQL

        query(statement, schema_name, storage_name, column_name).first > 0
      end

      # TODO: document
      # @api semipublic
      def upgrade_model_storage(model)
        properties = model.properties_with_subclasses(name)

        if success = create_model_storage(model)
          return properties
        end

        table_name = model.storage_name(name)

        with_connection do |connection|
          properties.map do |property|
            schema_hash = property_schema_hash(property)
            next if field_exists?(table_name, schema_hash[:name])

            statement = alter_table_add_column_statement(connection, table_name, schema_hash)
            command   = connection.create_command(statement)
            command.execute_non_query

            property
          end.compact
        end
      end

      # TODO: document
      # @api semipublic
      def create_model_storage(model)
        properties = model.properties_with_subclasses(name)

        return false if storage_exists?(model.storage_name(name))
        return false if properties.empty?

        with_connection do |connection|
          statement = create_table_statement(connection, model, properties)
          command   = connection.create_command(statement)
          command.execute_non_query

          (create_index_statements(model) + create_unique_index_statements(model)).each do |statement|
            command   = connection.create_command(statement)
            command.execute_non_query
          end
        end

        true
      end

      # TODO: document
      # @api semipublic
      def destroy_model_storage(model)
        return true unless supports_drop_table_if_exists? || storage_exists?(model.storage_name(name))
        execute(drop_table_statement(model))
        true
      end

      module SQL #:nodoc:
#        private  ## This cannot be private for current migrations

        # Adapters that support AUTO INCREMENT fields for CREATE TABLE
        # statements should overwrite this to return true
        #
        # @api private
        def supports_serial?
          false
        end

        # TODO: document
        # @api private
        def supports_drop_table_if_exists?
          false
        end

        # TODO: document
        # @api private
        def schema_name
          raise NotImplementedError, "#{self.class}#schema_name not implemented"
        end

        # TODO: document
        # @api private
        def alter_table_add_column_statement(connection, table_name, schema_hash)
          "ALTER TABLE #{quote_name(table_name)} ADD COLUMN #{property_schema_statement(connection, schema_hash)}"
        end

        # TODO: document
        # @api private
        def create_table_statement(connection, model, properties)
          statement = <<-SQL.compress_lines
            CREATE TABLE #{quote_name(model.storage_name(name))}
            (#{properties.map { |property| property_schema_statement(connection, property_schema_hash(property)) }.join(', ')},
            PRIMARY KEY(#{ properties.key.map { |property| quote_name(property.field) }.join(', ')}))
          SQL

          statement
        end

        # TODO: document
        # @api private
        def drop_table_statement(model)
          if supports_drop_table_if_exists?
            "DROP TABLE IF EXISTS #{quote_name(model.storage_name(name))}"
          else
            "DROP TABLE #{quote_name(model.storage_name(name))}"
          end
        end

        # TODO: document
        # @api private
        def create_index_statements(model)
          table_name = model.storage_name(name)
          model.properties(name).indexes.map do |index_name, fields|
            <<-SQL.compress_lines
              CREATE INDEX #{quote_name("index_#{table_name}_#{index_name}")} ON
              #{quote_name(table_name)} (#{fields.map { |field| quote_name(field) }.join(', ')})
            SQL
          end
        end

        # TODO: document
        # @api private
        def create_unique_index_statements(model)
          table_name = model.storage_name(name)
          model.properties(name).unique_indexes.map do |index_name, fields|
            <<-SQL.compress_lines
              CREATE UNIQUE INDEX #{quote_name("unique_#{table_name}_#{index_name}")} ON
              #{quote_name(table_name)} (#{fields.map { |field| quote_name(field) }.join(', ')})
            SQL
          end
        end

        # TODO: document
        # @api private
        def property_schema_hash(property)
          schema = (self.class.type_map[property.type] || self.class.type_map[property.primitive]).merge(:name => property.field)

          # TODO: figure out a way to specify the size not be included, even if
          # a default is defined in the typemap
          #  - use this to make it so all TEXT primitive fields do not have size
          if property.primitive == String && schema[:primitive] != 'TEXT'
            schema[:size] = property.length
          elsif property.primitive == BigDecimal || property.primitive == Float
            schema[:precision] = property.precision
            schema[:scale]     = property.scale
          end

          schema[:nullable?] = property.nullable?
          schema[:serial?]   = property.serial?

          if property.default.nil? || property.default.respond_to?(:call)
            # remove the default if the property is not nullable
            schema.delete(:default) unless property.nullable?
          else
            if property.type.respond_to?(:dump)
              schema[:default] = property.type.dump(property.default, property)
            else
              schema[:default] = property.default
            end
          end

          schema
        end

        # TODO: document
        # @api private
        def property_schema_statement(connection, schema)
          statement = quote_name(schema[:name])
          statement << " #{schema[:primitive]}"

          if schema[:precision] && schema[:scale]
            statement << "(#{[ :precision, :scale ].map { |key| connection.quote_value(schema[key]) }.join(', ')})"
          elsif schema[:size]
            statement << "(#{connection.quote_value(schema[:size])})"
          end

          statement << " DEFAULT #{connection.quote_value(schema[:default])}" if schema.key?(:default)
          statement << ' NOT NULL' unless schema[:nullable?]
          statement
        end
      end # module SQL

      include SQL

      module ClassMethods
        # Default types for all data object based adapters.
        #
        # @return [Hash] default types for data objects adapters.
        #
        # @api private
        def type_map
          size      = Property::DEFAULT_LENGTH
          precision = Property::DEFAULT_PRECISION
          scale     = Property::DEFAULT_SCALE_BIGDECIMAL

          @type_map ||= {
            Integer       => { :primitive => 'INTEGER'                                           },
            String        => { :primitive => 'VARCHAR', :size => size                            },
            Class         => { :primitive => 'VARCHAR', :size => size                            },
            BigDecimal    => { :primitive => 'DECIMAL', :precision => precision, :scale => scale },
            Float         => { :primitive => 'FLOAT',   :precision => precision                  },
            DateTime      => { :primitive => 'TIMESTAMP'                                         },
            Date          => { :primitive => 'DATE'                                              },
            Time          => { :primitive => 'TIMESTAMP'                                         },
            TrueClass     => { :primitive => 'BOOLEAN'                                           },
            Types::Object => { :primitive => 'TEXT'                                              },
            Types::Text   => { :primitive => 'TEXT'                                              },
          }.freeze
        end
      end # module ClassMethods
    end # module DataObjectsAdapter

    module MysqlAdapter
      DEFAULT_ENGINE        = 'InnoDB'.freeze
      DEFAULT_CHARACTER_SET = 'utf8'.freeze
      DEFAULT_COLLATION     = 'utf8_general_ci'.freeze

      # TODO: document
      # @api private
      def self.included(base)
        base.extend ClassMethods
      end

      # TODO: document
      # @api semipublic
      def storage_exists?(storage_name)
        query('SHOW TABLES LIKE ?', storage_name).first == storage_name
      end

      # TODO: document
      # @api semipublic
      def field_exists?(storage_name, field)
        result = query("SHOW COLUMNS FROM #{quote_name(storage_name)} LIKE ?", field).first
        result ? result.field == field : false
      end

      module SQL #:nodoc:
#        private  ## This cannot be private for current migrations

        # TODO: document
        # @api private
        def supports_serial?
          true
        end

        # TODO: document
        # @api private
        def supports_drop_table_if_exists?
          true
        end

        # TODO: document
        # @api private
        def schema_name
          # TODO: is there a cleaner way to find out the current DB we are connected to?
          normalized_uri.path.split('/').last
        end

        # TODO: update dkubb/dm-more/dm-migrations to use schema_name and remove this
        alias db_name schema_name

        # TODO: document
        # @api private
        def create_table_statement(connection, model, properties)
          "#{super} ENGINE = #{DEFAULT_ENGINE} CHARACTER SET #{character_set} COLLATE #{collation}"
        end

        # TODO: document
        # @api private
        def property_schema_hash(property)
          schema = super

          if schema[:primitive] == 'TEXT'
            schema.delete(:default)
          end

          schema
        end

        # TODO: document
        # @api private
        def property_schema_statement(connection, schema)
          statement = super

          if supports_serial? && schema[:serial?]
            statement << ' AUTO_INCREMENT'
          end

          statement
        end

        # TODO: document
        # @api private
        def character_set
          @character_set ||= show_variable('character_set_connection') || DEFAULT_CHARACTER_SET
        end

        # TODO: document
        # @api private
        def collation
          @collation ||= show_variable('collation_connection') || DEFAULT_COLLATION
        end

        # TODO: document
        # @api private
        def show_variable(name)
          result = query('SHOW VARIABLES LIKE ?', name).first
          result ? result.value.freeze : nil
        end
      end # module SQL

      include SQL

      module ClassMethods
        # Types for MySQL databases.
        #
        # @return [Hash] types for MySQL databases.
        #
        # @api private
        def type_map
          @type_map ||= super.merge(
            DateTime => { :primitive => 'DATETIME' },
            Time     => { :primitive => 'DATETIME' }
          ).freeze
        end
      end # module ClassMethods
    end # module MysqlAdapter

    module PostgresAdapter
      # TODO: document
      # @api private
      def self.included(base)
        base.extend ClassMethods
      end

      # TODO: document
      # @api semipublic
      def upgrade_model_storage(model)
        without_notices { super }
      end

      # TODO: document
      # @api semipublic
      def create_model_storage(model)
        without_notices { super }
      end

      # TODO: document
      # @api semipublic
      def destroy_model_storage(model)
        if supports_drop_table_if_exists?
          without_notices { super }
        else
          super
        end
      end

      module SQL #:nodoc:
#        private  ## This cannot be private for current migrations

        # TODO: document
        # @api private
        def supports_drop_table_if_exists?
          @supports_drop_table_if_exists ||= postgres_version >= '8.2'
        end

        # TODO: document
        # @api private
        def schema_name
          @schema_name ||= query('SELECT current_schema()').first.freeze
        end

        # TODO: document
        # @api private
        def postgres_version
          @postgres_version ||= query('SELECT version()').first.split[1].freeze
        end

        # TODO: document
        # @api private
        def without_notices
          # execute the block with NOTICE messages disabled
          begin
            execute('SET client_min_messages = warning')
            yield
          ensure
            execute('RESET client_min_messages')
          end
        end

        # TODO: document
        # @api private
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
        # Types for PostgreSQL databases.
        #
        # @return [Hash] types for PostgreSQL databases.
        #
        # @api private
        def type_map
          precision = Property::DEFAULT_PRECISION
          scale     = Property::DEFAULT_SCALE_BIGDECIMAL

          @type_map ||= super.merge(
            BigDecimal => { :primitive => 'NUMERIC', :precision => precision, :scale => scale },
            Float      => { :primitive => 'DOUBLE PRECISION'                                  }
          ).freeze
        end
      end # module ClassMethods
    end # module PostgresAdapter

    module Sqlite3Adapter
      # TODO: document
      # @api private
      def self.included(base)
        base.extend ClassMethods
      end

      # TODO: document
      # @api semipublic
      def storage_exists?(storage_name)
        query_table(storage_name).size > 0
      end

      # TODO: document
      # @api semipublic
      def field_exists?(storage_name, column_name)
        query_table(storage_name).any? do |row|
          row.name == column_name
        end
      end

      module SQL #:nodoc:
#        private  ## This cannot be private for current migrations

        # TODO: document
        # @api private
        def supports_serial?
          @supports_serial ||= sqlite_version >= '3.1.0'
        end

        # TODO: document
        # @api private
        def supports_drop_table_if_exists?
          @supports_drop_table_if_exists ||= sqlite_version >= '3.3.0'
        end

        # TODO: document
        # @api private
        def query_table(table_name)
          query("PRAGMA table_info(#{quote_name(table_name)})")
        end

        # TODO: document
        # @api private
        def create_table_statement(connection, model, properties)
          statement = <<-SQL.compress_lines
            CREATE TABLE #{quote_name(model.storage_name(name))}
            (#{properties.map { |property| property_schema_statement(connection, property_schema_hash(property)) }.join(', ')}
          SQL

          # skip adding the primary key if one of the columns is serial.  In
          # SQLite the serial column must be the primary key, so it has already
          # been defined
          unless properties.any? { |property| property.serial? }
            statement << ", PRIMARY KEY(#{properties.key.map { |property| quote_name(property.field) }.join(', ')})"
          end

          statement << ')'
          statement
        end

        # TODO: document
        # @api private
        def property_schema_statement(connection, schema)
          statement = super

          if supports_serial? && schema[:serial?]
            statement << ' PRIMARY KEY AUTOINCREMENT'
          end

          statement
        end

        # TODO: document
        # @api private
        def sqlite_version
          @sqlite_version ||= query('SELECT sqlite_version(*)').first.freeze
        end
      end # module SQL

      include SQL

      module ClassMethods
        # Types for SQLite 3 databases.
        #
        # @return [Hash] types for SQLite 3 databases.
        #
        # @api private
        def type_map
          @type_map ||= super.merge(Class => { :primitive => 'VARCHAR' }).freeze
        end
      end # module ClassMethods
    end # module Sqlite3Adapter

    module Repository
      ##
      # Determine whether a particular named storage exists in this repository
      #
      # @param [String]
      #   storage_name name of the storage to test for
      #
      # @return [TrueClass, FalseClass]
      #   true if the data-store +storage_name+ exists
      #
      # @api semipublic
      def storage_exists?(storage_name)
        if adapter.respond_to?(:storage_exists?)
          adapter.storage_exists?(storage_name)
        end
      end

      # TODO: document
      # @api semipublic
      def upgrade_model_storage(model)
        if adapter.respond_to?(:upgrade_model_storage)
          adapter.upgrade_model_storage(model)
        end
      end

      # TODO: document
      # @api semipublic
      def create_model_storage(model)
        if adapter.respond_to?(:create_model_storage)
          adapter.create_model_storage(model)
        end
      end

      # TODO: document
      # @api semipublic
      def destroy_model_storage(model)
        if adapter.respond_to?(:destroy_model_storage)
          adapter.destroy_model_storage(model)
        end
      end

      ##
      # Destructively automigrates the data-store to match the model.
      # First migrates all models down and then up.
      # REPEAT: THIS IS DESTRUCTIVE
      #
      # @api public
      def auto_migrate!
        DataMapper.auto_migrate!(name)
      end

      ##
      # Safely migrates the data-store to match the model
      # preserving data already in the data-store
      #
      # @api public
      def auto_upgrade!
        DataMapper.auto_upgrade!(name)
      end
    end # module Repository

    module Model
      # TODO: document
      # @api private
      def self.included(mod)
        mod.descendants.each { |model| model.extend self }
      end

      # TODO: document
      # @api semipublic
      def storage_exists?(repository_name = default_repository_name)
        repository(repository_name).storage_exists?(storage_name(repository_name))
      end

      ##
      # Destructively automigrates the data-store to match the model
      # REPEAT: THIS IS DESTRUCTIVE
      #
      # @param Symbol repository_name the repository to be migrated
      #
      # @api public
      def auto_migrate!(repository_name = self.repository_name)
        assert_valid
        auto_migrate_down!(repository_name)
        auto_migrate_up!(repository_name)
      end

      ##
      # Safely migrates the data-store to match the model
      # preserving data already in the data-store
      #
      # @param Symbol repository_name the repository to be migrated
      #
      # @api public
      def auto_upgrade!(repository_name = self.repository_name)
        assert_valid
        if base_model == self
          repository(repository_name).upgrade_model_storage(self)
        else
          base_model.auto_upgrade!(repository_name)
        end
      end

      ##
      # Destructively migrates the data-store down, which basically
      # deletes all the models.
      # REPEAT: THIS IS DESTRUCTIVE
      #
      # @param Symbol repository_name the repository to be migrated
      #
      # @api private
      def auto_migrate_down!(repository_name = self.repository_name)
        assert_valid
        if base_model == self
          repository(repository_name).destroy_model_storage(self)
        else
          base_model.auto_migrate_down!(repository_name)
        end
      end

      ##
      # Auto migrates the data-store to match the model
      #
      # @param Symbol repository_name the repository to be migrated
      #
      # @api private
      def auto_migrate_up!(repository_name = self.repository_name)
        assert_valid
        if base_model == self
          repository(repository_name).create_model_storage(self)
        else
          base_model.auto_migrate_up!(repository_name)
        end
      end
    end # module Model
  end

  module Adapters
    extendable do

      # TODO: document
      # @api private
      def const_added(const_name)
        if DataMapper::Migrations.const_defined?(const_name)
          adapter = const_get(const_name)
          adapter.send(:include, DataMapper::Migrations.const_get(const_name))
        end

        super
      end
    end
  end # module Adapters
end # module DataMapper
