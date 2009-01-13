# TODO: move to dm-more/dm-migrations

module DataMapper
  ##
  # destructively migrates the repository upwards to match model definitions
  #
  # @param [Symbol] name repository to act on, :default is the default
  def self.migrate!(repository_name = Repository.default_name)
    repository(repository_name).migrate!
  end

  ##
  # drops and recreates the repository upwards to match model definitions
  #
  # @param [Symbol] name repository to act on, :default is the default
  def self.auto_migrate!(repository_name = nil)
    repository(repository_name).auto_migrate
  end

  def self.auto_upgrade!(repository_name = nil)
    repository(repository_name).auto_upgrade
  end

  module Migrations
    module DataObjectsAdapter
      def self.included(base)
        base.extend ClassMethods
      end

      ##
      # Returns whether the storage_name exists.
      #
      # @param [String] storage_name
      #   a String defining the name of a storage, for example a table name.
      #
      # @return [TrueClass, FalseClass]
      #   true if the storage exists
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
      # @param [String] field_name
      #   a String defining the name of a field, for example a column name.
      #
      # @return [TrueClass, FalseClass]
      #   true if the field exists.
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

      def upgrade_model_storage(model)
        properties = model.properties_with_subclasses(name)

        if success = create_model_storage(model)
          return properties
        end

        table_name = model.storage_name(name)

        properties.map do |property|
          schema_hash = property_schema_hash(property)
          next if field_exists?(table_name, schema_hash[:name])
          statement = alter_table_add_column_statement(table_name, schema_hash)
          execute(statement)
          property
        end.compact
      end

      def create_model_storage(model)
        properties = model.properties_with_subclasses(name)

        return false if storage_exists?(model.storage_name(name))
        return false if properties.empty?

        execute(create_table_statement(model, properties))

        (create_index_statements(model) + create_unique_index_statements(model)).each do |sql|
          execute(sql)
        end

        true
      end

      def destroy_model_storage(model)
        return true unless supports_drop_table_if_exists? || storage_exists?(model.storage_name(name))
        execute(drop_table_statement(model))
        true
      end

      module SQL
#        private  ## This cannot be private for current migrations

        # Adapters that support AUTO INCREMENT fields for CREATE TABLE
        # statements should overwrite this to return true
        #
        def supports_serial?
          false
        end

        def supports_drop_table_if_exists?
          false
        end

        def schema_name
          raise NotImplementedError
        end

        def alter_table_add_column_statement(table_name, schema_hash)
          "ALTER TABLE #{quote_name(table_name)} ADD COLUMN #{property_schema_statement(schema_hash)}"
        end

        def create_table_statement(model, properties)
          statement = <<-SQL.compress_lines
            CREATE TABLE #{quote_name(model.storage_name(name))}
            (#{properties.map { |p| property_schema_statement(property_schema_hash(p)) }.join(', ')},
            PRIMARY KEY(#{ properties.key.map { |p| quote_name(p.field) }.join(', ')}))
          SQL

          statement
        end

        def drop_table_statement(model)
          if supports_drop_table_if_exists?
            "DROP TABLE IF EXISTS #{quote_name(model.storage_name(name))}"
          else
            "DROP TABLE #{quote_name(model.storage_name(name))}"
          end
        end

        def create_index_statements(model)
          table_name = model.storage_name(name)
          model.properties(name).indexes.map do |index_name, fields|
            <<-SQL.compress_lines
              CREATE INDEX #{quote_name("index_#{table_name}_#{index_name}")} ON
              #{quote_name(table_name)} (#{fields.map { |f| quote_name(f) }.join(', ')})
            SQL
          end
        end

        def create_unique_index_statements(model)
          table_name = model.storage_name(name)
          model.properties(name).unique_indexes.map do |index_name, fields|
            <<-SQL.compress_lines
              CREATE UNIQUE INDEX #{quote_name("unique_#{table_name}_#{index_name}")} ON
              #{quote_name(table_name)} (#{fields.map { |f| quote_name(f) }.join(', ')})
            SQL
          end
        end

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

        def property_schema_statement(schema)
          statement = quote_name(schema[:name])
          statement << " #{schema[:primitive]}"

          if schema[:precision] && schema[:scale]
            statement << "(#{[ :precision, :scale ].map { |k| quote_value(schema[k]) }.join(',')})"
          elsif schema[:size]
            statement << "(#{quote_value(schema[:size])})"
          end

          statement << ' NOT NULL' unless schema[:nullable?]
          statement << " DEFAULT #{quote_value(schema[:default])}" if schema.key?(:default)
          statement
        end
      end # module SQL

      include SQL

      module ClassMethods
        # Default types for all data object based adapters.
        #
        # @return [Hash] default types for data objects adapters.
        def type_map
          size      = Property::DEFAULT_LENGTH
          precision = Property::DEFAULT_PRECISION
          scale     = Property::DEFAULT_SCALE_BIGDECIMAL

          @type_map ||= {
            Integer                   => { :primitive => 'INT'                                               },
            String                    => { :primitive => 'VARCHAR', :size => size                            },
            Class                     => { :primitive => 'VARCHAR', :size => size                            },
            BigDecimal                => { :primitive => 'DECIMAL', :precision => precision, :scale => scale },
            Float                     => { :primitive => 'FLOAT',   :precision => precision                  },
            DateTime                  => { :primitive => 'TIMESTAMP'                                         },
            Date                      => { :primitive => 'DATE'                                              },
            Time                      => { :primitive => 'TIMESTAMP'                                         },
            TrueClass                 => { :primitive => 'BOOLEAN'                                           },
            DataMapper::Types::Object => { :primitive => 'TEXT'                                              },
            DataMapper::Types::Text   => { :primitive => 'TEXT'                                              },
          }.freeze
        end
      end # module ClassMethods
    end # module DataObjectsAdapter

    module MysqlAdapter
      def self.included(base)
        base.extend ClassMethods
      end

      def storage_exists?(storage_name)
        query('SHOW TABLES LIKE ?', storage_name).first == storage_name
      end

      def field_exists?(storage_name, field_name)
        result = query("SHOW COLUMNS FROM #{quote_name(storage_name)} LIKE ?", field_name).first
        result ? result.field == field_name : false
      end

      private

      def schema_name
        raise NotImplementedError
      end

      module SQL
#        private  ## This cannot be private for current migrations

        def supports_serial?
          true
        end

        def supports_drop_table_if_exists?
          true
        end

        def schema_name
          # TODO: is there a cleaner way to find out the current DB we are connected to?
          @uri.path.split('/').last
        end

        # TODO: update dkubb/dm-more/dm-migrations to use schema_name and remove this
        alias db_name schema_name

        def create_table_statement(model, properties)
          "#{super} ENGINE = InnoDB CHARACTER SET #{character_set} COLLATE #{collation}"
        end

        def property_schema_hash(property)
          schema = super

          if schema[:primitive] == 'TEXT'
            schema.delete(:default)
          end

          schema
        end

        def property_schema_statement(schema)
          statement = super

          if supports_serial? && schema[:serial?]
            statement << ' AUTO_INCREMENT'
          end

          statement
        end

        def character_set
          @character_set ||= show_variable('character_set_connection') || 'utf8'
        end

        def collation
          @collation ||= show_variable('collation_connection') || 'utf8_general_ci'
        end

        def show_variable(name)
          result = query('SHOW VARIABLES LIKE ?', name).first
          result ? result.value : nil
        end
      end # module SQL

      include SQL

      module ClassMethods
        # Types for MySQL databases.
        #
        # @return [Hash] types for MySQL databases.
        def type_map
          @type_map ||= super.merge(
            Integer   => { :primitive => 'INT',     :size => 11 },
            TrueClass => { :primitive => 'TINYINT', :size => 1  },  # TODO: map this to a BIT or CHAR(0) field?
            Object    => { :primitive => 'TEXT'                 },
            DateTime  => { :primitive => 'DATETIME'             },
            Time      => { :primitive => 'DATETIME'             }
          )
        end
      end # module ClassMethods
    end # module MysqlAdapter

    module PostgresAdapter
      def self.included(base)
        base.extend ClassMethods
      end

      def upgrade_model_storage(model)
        without_notices { super }
      end

      def create_model_storage(model)
        without_notices { super }
      end

      def destroy_model_storage(model)
        if supports_drop_table_if_exists?
          without_notices { super }
        else
          super
        end
      end

      protected

      module SQL
#        private  ## This cannot be private for current migrations

        def supports_drop_table_if_exists?
          @supports_drop_table_if_exists ||= postgres_version >= '8.2'
        end

        def schema_name
          @schema_name ||= query('SELECT current_schema()').first
        end

        def postgres_version
          @postgres_version ||= query('SELECT version()').first.split[1]
        end

        def without_notices
          # execute the block with NOTICE messages disabled
          begin
            execute('SET client_min_messages = warning')
            yield
          ensure
            execute('RESET client_min_messages')
          end
        end

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
        def type_map
          precision = Property::DEFAULT_PRECISION
          scale     = Property::DEFAULT_SCALE_BIGDECIMAL

          @type_map ||= super.merge(
            Integer    => { :primitive => 'INTEGER'                                           },
            BigDecimal => { :primitive => 'NUMERIC', :precision => precision, :scale => scale },
            Float      => { :primitive => 'DOUBLE PRECISION'                                  }
          )
        end
      end # module ClassMethods
    end # class PostgresAdapter

    module Sqlite3Adapter
      def self.included(base)
        base.extend ClassMethods
      end

      def storage_exists?(storage_name)
        query_table(storage_name).size > 0
      end

      def field_exists?(storage_name, column_name)
        query_table(storage_name).any? do |row|
          row.name == column_name
        end
      end

      private

      def query_table(table_name)
        query('PRAGMA table_info(?)', table_name)
      end

      module SQL
#        private  ## This cannot be private for current migrations

        def supports_serial?
          @supports_serial ||= sqlite_version >= '3.1.0'
        end

        def supports_drop_table_if_exists?
          @supports_drop_table_if_exists ||= sqlite_version >= '3.3.0'
        end

        def create_table_statement(model, properties)
          statement = <<-SQL.compress_lines
            CREATE TABLE #{quote_name(model.storage_name(name))}
            (#{properties.map { |p| property_schema_statement(property_schema_hash(p)) }.join(', ')}
          SQL

          # skip adding the primary key if one of the columns is serial.  In
          # SQLite the serial column must be the primary key, so it has already
          # been defined
          unless properties.any? { |p| p.serial? }
            statement << ", PRIMARY KEY(#{properties.key.map { |p| quote_name(p.field) }.join(', ')})"
          end

          statement << ')'
          statement
        end

        def property_schema_statement(schema)
          statement = super

          if supports_serial? && schema[:serial?]
            statement << ' PRIMARY KEY AUTOINCREMENT'
          end

          statement
        end

        def sqlite_version
          @sqlite_version ||= query('SELECT sqlite_version(*)').first
        end
      end # module SQL

      include SQL

      module ClassMethods
        # Types for SQLite 3 databases.
        #
        # @return [Hash] types for SQLite 3 databases.
        def type_map
          @type_map ||= super.merge(
            Integer => { :primitive => 'INTEGER' },
            Class   => { :primitive => 'VARCHAR' }
          )
        end
      end # module ClassMethods
    end # module Sqlite3Adapter

    module Repository
      ##
      # Determine whether a particular named storage exists in this repository
      #
      # @param [String] storage_name name of the storage to test for
      # @return [TrueClass, FalseClass] true if the data-store +storage_name+ exists
      def storage_exists?(storage_name)
        adapter.storage_exists?(storage_name)
      end

      def upgrade_model_storage(model)
        adapter.upgrade_model_storage(model)
      end

      def create_model_storage(model)
        adapter.create_model_storage(model)
      end

      def destroy_model_storage(model)
        adapter.destroy_model_storage(model)
      end

      ##
      # Destructively automigrates the data-store to match the model.
      # First migrates all models down and then up.
      # REPEAT: THIS IS DESTRUCTIVE
      #
      # @api public
      def auto_migrate!
        auto_migrate_down
        auto_migrate_up
      end

      ##
      # Safely migrates the data-store to match the model
      # preserving data already in the data-store
      #
      # @api public
      def auto_upgrade!
        DataMapper::Resource.descendants.each do |model|
          model.auto_upgrade!(name)
        end
      end

      private

      ##
      # Destructively automigrates the data-store down
      # REPEAT: THIS IS DESTRUCTIVE
      #
      # @api private
      def auto_migrate_down
        DataMapper::Resource.descendants.each do |model|
          model.auto_migrate_down!(name)
        end
      end

      ##
      # Automigrates the data-store up
      #
      # @api private
      def auto_migrate_up
        DataMapper::Resource.descendants.each do |model|
          model.auto_migrate_up!(name)
        end
      end
    end # module Repository

    module Model
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
        auto_migrate_down!(repository_name)
        auto_migrate_up!(repository_name)
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
        if base_model == self
          repository(repository_name).destroy_model_storage(self)
        else
          base_model.auto_migrate!(repository_name)
        end
      end

      ##
      # Auto migrates the data-store to match the model
      #
      # @param Symbol repository_name the repository to be migrated
      #
      # @api private
      def auto_migrate_up!(repository_name = self.repository_name)
        if base_model == self
          repository(repository_name).create_model_storage(self)
        else
          base_model.auto_migrate!(repository_name)
        end
      end

      ##
      # Safely migrates the data-store to match the model
      # preserving data already in the data-store
      #
      # @param Symbol repository_name the repository to be migrated
      #
      # @api private
      def auto_upgrade!(repository_name = self.repository_name)
        repository(repository_name).upgrade_model_storage(self)
      end
    end # module Model
  end

  module Adapters
    extendable do
      def const_added(const_name)
        base = const_get(const_name)

        case const_name
          when :DataObjectsAdapter
            base.send(:include, Migrations.const_get(const_name))

          when :MysqlAdapter, :PostgresAdapter, :Sqlite3Adapter
            base.send(:include, Migrations.const_get(const_name))

            [ :Repository, :Model ].each do |name|
              DataMapper.const_get(name).send(:include, Migrations.const_get(name))
            end
        end

        super
      end
    end
  end # module Adapters
end # module DataMapper
