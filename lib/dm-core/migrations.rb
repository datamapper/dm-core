# TODO: move to dm-more/dm-migrations

module DataMapper
  module Migrations
    module SingletonMethods
      # destructively migrates the repository upwards to match model definitions
      #
      # @param [Symbol] name repository to act on, :default is the default
      #
      # @api public
      def migrate!(repository_name = nil)
        repository(repository_name).migrate!
      end

      # drops and recreates the repository upwards to match model definitions
      #
      # @param [Symbol] name repository to act on, :default is the default
      #
      # @api public
      def auto_migrate!(repository_name = nil)
        auto_migrate_down!(repository_name)
        auto_migrate_up!(repository_name)
      end

      # @api public
      def auto_upgrade!(repository_name = nil)
        repository_execute(:auto_upgrade!, repository_name)
      end

      private

      # @api private
      def auto_migrate_down!(repository_name)
        repository_execute(:auto_migrate_down!, repository_name)
      end

      # @api private
      def auto_migrate_up!(repository_name)
        repository_execute(:auto_migrate_up!, repository_name)
      end

      # @api private
      def repository_execute(method, repository_name)
        DataMapper::Model.descendants.each do |model|
          model.send(method, repository_name || model.default_repository_name)
        end
      end
    end

    module DataObjectsAdapter
      # @api private
      def self.included(base)
        base.extend ClassMethods

        DataMapper.extend(Migrations::SingletonMethods)

        [ :Repository, :Model ].each do |name|
          DataMapper.const_get(name).send(:include, Migrations.const_get(name))
        end
      end

      # Returns whether the storage_name exists.
      #
      # @param [String] storage_name
      #   a String defining the name of a storage, for example a table name.
      #
      # @return [Boolean]
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

        select(statement, schema_name, storage_name).first > 0
      end

      # Returns whether the field exists.
      #
      # @param [String] storage_name
      #   a String defining the name of a storage, for example a table name.
      # @param [String] field
      #   a String defining the name of a field, for example a column name.
      #
      # @return [Boolean]
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

        select(statement, schema_name, storage_name, column_name).first > 0
      end

      # @api semipublic
      def upgrade_model_storage(model)
        name       = self.name
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

      # @api semipublic
      def create_model_storage(model)
        name       = self.name
        properties = model.properties_with_subclasses(name)

        return false if storage_exists?(model.storage_name(name))
        return false if properties.empty?

        with_connection do |connection|
          statements = [ create_table_statement(connection, model, properties) ]
          statements.concat(create_index_statements(model))
          statements.concat(create_unique_index_statements(model))

          statements.each do |statement|
            command   = connection.create_command(statement)
            command.execute_non_query
          end
        end

        true
      end

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

        # @api private
        def supports_drop_table_if_exists?
          false
        end

        # @api private
        def schema_name
          raise NotImplementedError, "#{self.class}#schema_name not implemented"
        end

        # @api private
        def alter_table_add_column_statement(connection, table_name, schema_hash)
          "ALTER TABLE #{quote_name(table_name)} ADD COLUMN #{property_schema_statement(connection, schema_hash)}"
        end

        # @api private
        def create_table_statement(connection, model, properties)
          statement = <<-SQL.compress_lines
            CREATE TABLE #{quote_name(model.storage_name(name))}
            (#{properties.map { |property| property_schema_statement(connection, property_schema_hash(property)) }.join(', ')},
            PRIMARY KEY(#{ properties.key.map { |property| quote_name(property.field) }.join(', ')}))
          SQL

          statement
        end

        # @api private
        def drop_table_statement(model)
          table_name = quote_name(model.storage_name(name))
          if supports_drop_table_if_exists?
            "DROP TABLE IF EXISTS #{table_name}"
          else
            "DROP TABLE #{table_name}"
          end
        end

        # @api private
        def create_index_statements(model)
          name       = self.name
          table_name = model.storage_name(name)
          model.properties(name).indexes.map do |index_name, fields|
            <<-SQL.compress_lines
              CREATE INDEX #{quote_name("index_#{table_name}_#{index_name}")} ON
              #{quote_name(table_name)} (#{fields.map { |field| quote_name(field) }.join(', ')})
            SQL
          end
        end

        # @api private
        def create_unique_index_statements(model)
          name       = self.name
          table_name = model.storage_name(name)
          model.properties(name).unique_indexes.map do |index_name, fields|
            <<-SQL.compress_lines
              CREATE UNIQUE INDEX #{quote_name("unique_#{table_name}_#{index_name}")} ON
              #{quote_name(table_name)} (#{fields.map { |field| quote_name(field) }.join(', ')})
            SQL
          end
        end

        # @api private
        def property_schema_hash(property)
          primitive = property.primitive
          type      = property.type
          type_map  = self.class.type_map

          schema = (type_map[type] || type_map[primitive]).merge(:name => property.field)

          schema_primitive = schema[:primitive]

          if primitive == String && schema_primitive != 'TEXT' && schema_primitive != 'CLOB' && schema_primitive != 'NVARCHAR'
            schema[:length] = property.length
          elsif primitive == BigDecimal || primitive == Float
            schema[:precision] = property.precision
            schema[:scale]     = property.scale
          end

          schema[:allow_nil] = property.allow_nil?
          schema[:serial]    = property.serial?

          default = property.default

          if default.nil? || default.respond_to?(:call)
            # remove the default if the property does not allow nil
            schema.delete(:default) unless schema[:allow_nil]
          else
            schema[:default] = if type.respond_to?(:dump)
              type.dump(default, property)
            else
              default
            end
          end

          schema
        end

        # @api private
        def property_schema_statement(connection, schema)
          statement = quote_name(schema[:name])
          statement << " #{schema[:primitive]}"

          length = schema[:length]

          if schema[:precision] && schema[:scale]
            statement << "(#{[ :precision, :scale ].map { |key| connection.quote_value(schema[key]) }.join(', ')})"
          elsif length == 'max'
            statement << '(max)'
          elsif length
            statement << "(#{connection.quote_value(length)})"
          end

          statement << " DEFAULT #{connection.quote_value(schema[:default])}" if schema.key?(:default)
          statement << ' NOT NULL' unless schema[:allow_nil]
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
          length    = Property::DEFAULT_LENGTH
          precision = Property::DEFAULT_PRECISION
          scale     = Property::DEFAULT_SCALE_BIGDECIMAL

          @type_map ||= {
            Integer     => { :primitive => 'INTEGER'                                           },
            String      => { :primitive => 'VARCHAR', :length => length                        },
            Class       => { :primitive => 'VARCHAR', :length => length                        },
            BigDecimal  => { :primitive => 'DECIMAL', :precision => precision, :scale => scale },
            Float       => { :primitive => 'FLOAT',   :precision => precision                  },
            DateTime    => { :primitive => 'TIMESTAMP'                                         },
            Date        => { :primitive => 'DATE'                                              },
            Time        => { :primitive => 'TIMESTAMP'                                         },
            TrueClass   => { :primitive => 'BOOLEAN'                                           },
            Types::Text => { :primitive => 'TEXT'                                              },
          }.freeze
        end
      end # module ClassMethods
    end # module DataObjectsAdapter

    module MysqlAdapter
      DEFAULT_ENGINE        = 'InnoDB'.freeze
      DEFAULT_CHARACTER_SET = 'utf8'.freeze
      DEFAULT_COLLATION     = 'utf8_unicode_ci'.freeze

      # @api private
      def self.included(base)
        base.extend ClassMethods
      end

      # @api semipublic
      def storage_exists?(storage_name)
        select('SHOW TABLES LIKE ?', storage_name).first == storage_name
      end

      # @api semipublic
      def field_exists?(storage_name, field)
        result = select("SHOW COLUMNS FROM #{quote_name(storage_name)} LIKE ?", field).first
        result ? result.field == field : false
      end

      module SQL #:nodoc:
#        private  ## This cannot be private for current migrations

        # @api private
        def supports_serial?
          true
        end

        # @api private
        def supports_drop_table_if_exists?
          true
        end

        # @api private
        def schema_name
          # TODO: is there a cleaner way to find out the current DB we are connected to?
          normalized_uri.path.split('/').last
        end

        # TODO: update dkubb/dm-more/dm-migrations to use schema_name and remove this
        alias db_name schema_name

        # @api private
        def create_table_statement(connection, model, properties)
          "#{super} ENGINE = #{DEFAULT_ENGINE} CHARACTER SET #{character_set} COLLATE #{collation}"
        end

        # @api private
        def property_schema_hash(property)
          schema = super

          if schema[:primitive] == 'TEXT'
            schema[:primitive] = text_column_statement(property.length)
            schema.delete(:default)
          end

          min = property.min
          max = property.max

          if property.primitive == Integer && min && max
            schema[:primitive] = integer_column_statement(min..max)
          end

          schema
        end

        # @api private
        def property_schema_statement(connection, schema)
          statement = super

          if supports_serial? && schema[:serial]
            statement << ' AUTO_INCREMENT'
          end

          statement
        end

        # @api private
        def character_set
          @character_set ||= show_variable('character_set_connection') || DEFAULT_CHARACTER_SET
        end

        # @api private
        def collation
          @collation ||= show_variable('collation_connection') || DEFAULT_COLLATION
        end

        # @api private
        def show_variable(name)
          result = select('SHOW VARIABLES LIKE ?', name).first
          result ? result.value.freeze : nil
        end

        private

        # Return SQL statement for the text column
        #
        # @param [Integer] length
        #   the max allowed length
        #
        # @return [String]
        #   the statement to create the text column
        #
        # @api private
        def text_column_statement(length)
          if    length < 2**8  then 'TINYTEXT'
          elsif length < 2**16 then 'TEXT'
          elsif length < 2**24 then 'MEDIUMTEXT'
          elsif length < 2**32 then 'LONGTEXT'

          # http://www.postgresql.org/files/documentation/books/aw_pgsql/node90.html
          # Implies that PostgreSQL doesn't have a size limit on text
          # fields, so this param validation happens here instead of
          # DM::Property#initialize.
          else
            raise ArgumentError, "length of #{length} exceeds maximum size supported"
          end
        end

        # Return SQL statement for the integer column
        #
        # @param [Range] range
        #   the min/max allowed integers
        #
        # @return [String]
        #   the statement to create the integer column
        #
        # @api private
        def integer_column_statement(range)
          '%s(%d)%s' % [
            integer_column_type(range),
            integer_display_size(range),
            integer_statement_sign(range),
          ]
        end

        # Return the integer column type
        #
        # Use the smallest available column type that will satisfy the
        # allowable range of numbers
        #
        # @param [Range] range
        #   the min/max allowed integers
        #
        # @return [String]
        #   the column type
        #
        # @api private
        def integer_column_type(range)
          if range.first < 0
            signed_integer_column_type(range)
          else
            unsigned_integer_column_type(range)
          end
        end

        # Return the signed integer column type
        #
        # @param [Range] range
        #   the min/max allowed integers
        #
        # @return [String]
        #
        # @api private
        def signed_integer_column_type(range)
          min = range.first
          max = range.last

          tinyint   = 2**7
          smallint  = 2**15
          integer   = 2**31
          mediumint = 2**23
          bigint    = 2**63

          if    min >= -tinyint   && max < tinyint   then 'TINYINT'
          elsif min >= -smallint  && max < smallint  then 'SMALLINT'
          elsif min >= -mediumint && max < mediumint then 'MEDIUMINT'
          elsif min >= -integer   && max < integer   then 'INT'
          elsif min >= -bigint    && max < bigint    then 'BIGINT'
          else
            raise ArgumentError, "min #{min} and max #{max} exceeds supported range"
          end
        end

        # Return the unsigned integer column type
        #
        # @param [Range] range
        #   the min/max allowed integers
        #
        # @return [String]
        #
        # @api private
        def unsigned_integer_column_type(range)
          max = range.last

          if    max < 2**8  then 'TINYINT'
          elsif max < 2**16 then 'SMALLINT'
          elsif max < 2**24 then 'MEDIUMINT'
          elsif max < 2**32 then 'INT'
          elsif max < 2**64 then 'BIGINT'
          else
            raise ArgumentError, "min #{range.first} and max #{max} exceeds supported range"
          end
        end

        # Return the integer column display size
        #
        # Adjust the display size to match the maximum number of
        # expected digits. This is more for documentation purposes
        # and does not affect what can actually be stored in a
        # specific column
        #
        # @param [Range] range
        #   the min/max allowed integers
        #
        # @return [Integer]
        #   the display size for the integer
        #
        # @api private
        def integer_display_size(range)
          [ range.first.to_s.length, range.last.to_s.length ].max
        end

        # Return the integer sign statement
        #
        # @param [Range] range
        #   the min/max allowed integers
        #
        # @return [String, nil]
        #   statement if unsigned, nil if signed
        #
        # @api private
        def integer_statement_sign(range)
          ' UNSIGNED' unless range.first < 0
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
      # @api private
      def self.included(base)
        base.extend ClassMethods
      end

      # @api semipublic
      def upgrade_model_storage(model)
        without_notices { super }
      end

      # @api semipublic
      def create_model_storage(model)
        without_notices { super }
      end

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

        # @api private
        def supports_drop_table_if_exists?
          @supports_drop_table_if_exists ||= postgres_version >= '8.2'
        end

        # @api private
        def schema_name
          @schema_name ||= select('SELECT current_schema()').first.freeze
        end

        # @api private
        def postgres_version
          @postgres_version ||= select('SELECT version()').first.split[1].freeze
        end

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

        # @api private
        def property_schema_hash(property)
          schema = super

          primitive = property.primitive

          # Postgres does not support precision and scale for Float
          if primitive == Float
            schema.delete(:precision)
            schema.delete(:scale)
          end

          min = property.min
          max = property.max

          if primitive == Integer && min && max
            schema[:primitive] = integer_column_statement(min..max)
          end

          if schema[:serial]
            schema[:primitive] = serial_column_statement(min..max)
          end

          schema
        end

        private

        # Return SQL statement for the integer column
        #
        # @param [Range] range
        #   the min/max allowed integers
        #
        # @return [String]
        #   the statement to create the integer column
        #
        # @api private
        def integer_column_statement(range)
          min = range.first
          max = range.last

          smallint = 2**15
          integer  = 2**31
          bigint   = 2**63

          if    min >= -smallint && max < smallint then 'SMALLINT'
          elsif min >= -integer  && max < integer  then 'INTEGER'
          elsif min >= -bigint   && max < bigint   then 'BIGINT'
          else
            raise ArgumentError, "min #{min} and max #{max} exceeds supported range"
          end
        end

        # Return SQL statement for the serial column
        #
        # @param [Integer] max
        #   the max allowed integer
        #
        # @return [String]
        #   the statement to create the serial column
        #
        # @api private
        def serial_column_statement(range)
          max = range.last

          if    max.nil? || max < 2**31 then 'SERIAL'
          elsif             max < 2**63 then 'BIGSERIAL'
          else
            raise ArgumentError, "min #{range.first} and max #{max} exceeds supported range"
          end
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
            BigDecimal => { :primitive => 'NUMERIC',          :precision => precision, :scale => scale },
            Float      => { :primitive => 'DOUBLE PRECISION'                                           }
          ).freeze
        end
      end # module ClassMethods
    end # module PostgresAdapter

    module Sqlite3Adapter
      # @api private
      def self.included(base)
        base.extend ClassMethods
      end

      # @api semipublic
      def storage_exists?(storage_name)
        table_info(storage_name).any?
      end

      # @api semipublic
      def field_exists?(storage_name, column_name)
        table_info(storage_name).any? do |row|
          row.name == column_name
        end
      end

      module SQL #:nodoc:
#        private  ## This cannot be private for current migrations

        # @api private
        def supports_serial?
          @supports_serial ||= sqlite_version >= '3.1.0'
        end

        # @api private
        def supports_drop_table_if_exists?
          @supports_drop_table_if_exists ||= sqlite_version >= '3.3.0'
        end

        # @api private
        def table_info(table_name)
          select("PRAGMA table_info(#{quote_name(table_name)})")
        end

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

        # @api private
        def property_schema_statement(connection, schema)
          statement = super

          if supports_serial? && schema[:serial]
            statement << ' PRIMARY KEY AUTOINCREMENT'
          end

          statement
        end

        # @api private
        def sqlite_version
          @sqlite_version ||= select('SELECT sqlite_version(*)').first.freeze
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

    module OracleAdapter
      # @api private
      def self.included(base)
        base.extend ClassMethods
      end

      # @api semipublic
      def storage_exists?(storage_name)
        statement = <<-SQL.compress_lines
          SELECT COUNT(*)
          FROM all_tables
          WHERE owner = ?
          AND table_name = ?
        SQL

        select(statement, schema_name, oracle_upcase(storage_name)).first > 0
      end

      # @api semipublic
      def sequence_exists?(sequence_name)
        return false unless sequence_name
        statement = <<-SQL.compress_lines
          SELECT COUNT(*)
          FROM all_sequences
          WHERE sequence_owner = ?
          AND sequence_name = ?
        SQL

        select(statement, schema_name, oracle_upcase(sequence_name)).first > 0
      end

      # @api semipublic
      def field_exists?(storage_name, field_name)
        statement = <<-SQL.compress_lines
          SELECT COUNT(*)
          FROM all_tab_columns
          WHERE owner = ?
          AND table_name = ?
          AND column_name = ?
        SQL

        select(statement, schema_name, oracle_upcase(storage_name), oracle_upcase(field_name)).first > 0
      end

      # @api semipublic
      def storage_fields(storage_name)
        statement = <<-SQL.compress_lines
          SELECT column_name
          FROM all_tab_columns
          WHERE owner = ?
          AND table_name = ?
        SQL

        select(statement, schema_name, oracle_upcase(storage_name))
      end

      # @api semipublic
      def create_model_storage(model)
        name       = self.name
        properties = model.properties_with_subclasses(name)
        table_name = model.storage_name(name)
        truncate_or_delete = self.class.auto_migrate_with
        table_is_truncated = truncate_or_delete && @truncated_tables && @truncated_tables[table_name]

        return false if storage_exists?(table_name) && !table_is_truncated
        return false if properties.empty?

        with_connection do |connection|
          # if table was truncated then check if all columns for properties are present
          # TODO: check all other column definition options
          if table_is_truncated && storage_has_all_fields?(table_name, properties)
            @truncated_tables[table_name] = nil
          else
            # forced drop of table if properties are different
            if truncate_or_delete
              destroy_model_storage(model, true)
            end

            statements = [ create_table_statement(connection, model, properties) ]
            statements.concat(create_index_statements(model))
            statements.concat(create_unique_index_statements(model))
            statements.concat(create_sequence_statements(model))

            statements.each do |statement|
              command   = connection.create_command(statement)
              command.execute_non_query
            end
          end

        end

        true
      end

      # @api semipublic
      def destroy_model_storage(model, forced = false)
        table_name = model.storage_name(name)
        klass      = self.class
        truncate_or_delete = klass.auto_migrate_with
        if storage_exists?(table_name)
          if truncate_or_delete && !forced
            case truncate_or_delete
            when :truncate
              execute(truncate_table_statement(model))
            when :delete
              execute(delete_table_statement(model))
            else
              raise ArgumentError, "Unsupported auto_migrate_with option"
            end
            @truncated_tables ||= {}
            @truncated_tables[table_name] = true
          else
            execute(drop_table_statement(model))
            @truncated_tables[table_name] = nil if @truncated_tables
          end
        end
        # added destroy of sequences
        reset_sequences = klass.auto_migrate_reset_sequences
        table_is_truncated = @truncated_tables && @truncated_tables[table_name]
        unless truncate_or_delete && !reset_sequences && !forced
          if sequence_exists?(model_sequence_name(model))
            statement = if table_is_truncated && !forced
              reset_sequence_statement(model)
            else
              drop_sequence_statement(model)
            end
            execute(statement) if statement
          end
        end
        true
      end

      private

      def storage_has_all_fields?(table_name, properties)
        properties.map { |property| oracle_upcase(property.field) }.sort == storage_fields(table_name).sort
      end

      # If table or column name contains just lowercase characters then do uppercase
      # as uppercase version will be used in Oracle data dictionary tables
      def oracle_upcase(name)
        name =~ /[A-Z]/ ? name : name.upcase
      end

      module SQL #:nodoc:
#        private  ## This cannot be private for current migrations

        # @api private
        def schema_name
          @schema_name ||= select("SELECT SYS_CONTEXT('userenv','current_schema') FROM dual").first.freeze
        end

        # @api private
        def create_sequence_statements(model)
          name       = self.name
          table_name = model.storage_name(name)
          serial     = model.serial(name)

          statements = []
          if sequence_name = model_sequence_name(model)
            sequence_name = quote_name(sequence_name)
            column_name   = quote_name(serial.field)

            statements << <<-SQL.compress_lines
              CREATE SEQUENCE #{sequence_name} NOCACHE
            SQL

            # create trigger only if custom sequence name was not specified
            unless serial.options[:sequence]
              statements << <<-SQL.compress_lines
                CREATE OR REPLACE TRIGGER #{quote_name(default_trigger_name(table_name))}
                BEFORE INSERT ON #{quote_name(table_name)} FOR EACH ROW
                BEGIN
                  IF inserting THEN
                    IF :new.#{column_name} IS NULL THEN
                      SELECT #{sequence_name}.NEXTVAL INTO :new.#{column_name} FROM dual;
                    END IF;
                  END IF;
                END;
              SQL
            end
          end

          statements
        end

        # @api private
        def drop_sequence_statement(model)
          if sequence_name = model_sequence_name(model)
            "DROP SEQUENCE #{quote_name(sequence_name)}"
          else
            nil
          end
        end

        # @api private
        def reset_sequence_statement(model)
          if sequence_name = model_sequence_name(model)
            sequence_name = quote_name(sequence_name)
            <<-SQL.compress_lines
            DECLARE
              cval   INTEGER;
            BEGIN
              SELECT #{sequence_name}.NEXTVAL INTO cval FROM dual;
              EXECUTE IMMEDIATE 'ALTER SEQUENCE #{sequence_name} INCREMENT BY -' || cval || ' MINVALUE 0';
              SELECT #{sequence_name}.NEXTVAL INTO cval FROM dual;
              EXECUTE IMMEDIATE 'ALTER SEQUENCE #{sequence_name} INCREMENT BY 1';
            END;
            SQL
          else
            nil
          end

        end

        # @api private
        def truncate_table_statement(model)
          "TRUNCATE TABLE #{quote_name(model.storage_name(name))}"
        end

        # @api private
        def delete_table_statement(model)
          "DELETE FROM #{quote_name(model.storage_name(name))}"
        end

        private

        def model_sequence_name(model)
          name       = self.name
          table_name = model.storage_name(name)
          serial     = model.serial(name)

          if serial
            serial.options[:sequence] || default_sequence_name(table_name)
          else
            nil
          end
        end

        def default_sequence_name(table_name)
          # truncate table name if necessary to fit in max length of identifier
          "#{table_name[0,self.class::IDENTIFIER_MAX_LENGTH-4]}_seq"
        end

        def default_trigger_name(table_name)
          # truncate table name if necessary to fit in max length of identifier
          "#{table_name[0,self.class::IDENTIFIER_MAX_LENGTH-4]}_pkt"
        end

      end # module SQL

      include SQL

      module ClassMethods
        # Types for Oracle databases.
        #
        # @return [Hash] types for Oracle databases.
        #
        # @api private
        def type_map
          length    = Property::DEFAULT_LENGTH
          precision = Property::DEFAULT_PRECISION
          scale     = Property::DEFAULT_SCALE_BIGDECIMAL

          @type_map ||= {
            Integer     => { :primitive => 'NUMBER',   :precision => precision, :scale => 0   },
            String      => { :primitive => 'VARCHAR2', :length => length                      },
            Class       => { :primitive => 'VARCHAR2', :length => length                      },
            BigDecimal  => { :primitive => 'NUMBER',   :precision => precision, :scale => nil },
            Float       => { :primitive => 'BINARY_FLOAT',                                    },
            DateTime    => { :primitive => 'DATE'                                             },
            Date        => { :primitive => 'DATE'                                             },
            Time        => { :primitive => 'DATE'                                             },
            TrueClass   => { :primitive => 'NUMBER',  :precision => 1, :scale => 0            },
            Types::Text => { :primitive => 'CLOB'                                             },
          }.freeze
        end

        # Use table truncate or delete for auto_migrate! to speed up test execution
        #
        # @param [Symbol] :truncate, :delete or :drop_and_create (or nil)
        #   do not specify parameter to return current value
        #
        # @return [Symbol] current value of auto_migrate_with option (nil returned for :drop_and_create)
        #
        # @api semipublic
        def auto_migrate_with(value = :not_specified)
          return @auto_migrate_with if value == :not_specified
          value = nil if value == :drop_and_create
          raise ArgumentError unless [nil, :truncate, :delete].include?(value)
          @auto_migrate_with = value
        end

        # Set if sequences will or will not be reset during auto_migrate!
        #
        # @param [TrueClass, FalseClass] reset sequences?
        #   do not specify parameter to return current value
        #
        # @return [Symbol] current value of auto_migrate_reset_sequences option (default value is true)
        #
        # @api semipublic
        def auto_migrate_reset_sequences(value = :not_specified)
          return @auto_migrate_reset_sequences.nil? ? true : @auto_migrate_reset_sequences if value == :not_specified
          raise ArgumentError unless [true, false].include?(value)
          @auto_migrate_reset_sequences = value
        end

      end # module ClassMethods
    end # module PostgresAdapter

   module SqlserverAdapter
      DEFAULT_CHARACTER_SET = 'utf8'.freeze

      # @api private
      def self.included(base)
        base.extend ClassMethods
      end

      # @api semipublic
      def storage_exists?(storage_name)
        select("SELECT name FROM sysobjects WHERE name LIKE ?", storage_name).first == storage_name
      end

      # @api semipublic
      def field_exists?(storage_name, field_name)
        result = select("SELECT c.name FROM sysobjects as o JOIN syscolumns AS c ON o.id = c.id WHERE o.name = #{quote_name(storage_name)} AND c.name LIKE ?", field_name).first
        result ? result.field == field_name : false
      end

      module SQL #:nodoc:
#        private  ## This cannot be private for current migrations

        # @api private
        def supports_serial?
          true
        end

        # @api private
        def supports_drop_table_if_exists?
          false
        end

        # @api private
        def schema_name
          # TODO: is there a cleaner way to find out the current DB we are connected to?
          @options[:path].split('/').last
        end

        # TODO: update dkubb/dm-more/dm-migrations to use schema_name and remove this

        alias db_name schema_name

        # @api private
        def create_table_statement(connection, model, properties)
          statement = <<-SQL.compress_lines
            CREATE TABLE #{quote_name(model.storage_name(name))}
            (#{properties.map { |property| property_schema_statement(connection, property_schema_hash(property)) }.join(', ')}
          SQL

          unless properties.any? { |property| property.serial? }
            statement << ", PRIMARY KEY(#{properties.key.map { |property| quote_name(property.field) }.join(', ')})"
          end

          statement << ')'
          statement
        end

        # @api private
        def property_schema_hash(property)
          schema = super

          min = property.min
          max = property.max

          if property.primitive == Integer && min && max
            schema[:primitive] = integer_column_statement(min..max)
          end

          if schema[:primitive] == 'TEXT'
            schema.delete(:default)
          end

          schema
        end

        # @api private
        def property_schema_statement(connection, schema)
          if supports_serial? && schema[:serial]
            statement = quote_name(schema[:name])
            statement << " #{schema[:primitive]}"

            length = schema[:length]

            if schema[:precision] && schema[:scale]
              statement << "(#{[ :precision, :scale ].map { |key| connection.quote_value(schema[key]) }.join(', ')})"
            elsif length
              statement << "(#{connection.quote_value(length)})"
            end

            statement << ' IDENTITY'
          else
            statement = super
          end

          statement
        end

        # @api private
        def character_set
          @character_set ||= show_variable('character_set_connection') || DEFAULT_CHARACTER_SET
        end

        # @api private
        def collation
          @collation ||= show_variable('collation_connection') || DEFAULT_COLLATION
        end

        # @api private
        def show_variable(name)
          raise "SqlserverAdapter#show_variable: Not implemented"
        end

        private

        # Return SQL statement for the integer column
        #
        # @param [Range] range
        #   the min/max allowed integers
        #
        # @return [String]
        #   the statement to create the integer column
        #
        # @api private
        def integer_column_statement(range)
          min = range.first
          max = range.last

          smallint = 2**15
          integer  = 2**31
          bigint   = 2**63

          if    min >= 0         && max < 2**8     then 'TINYINT'
          elsif min >= -smallint && max < smallint then 'SMALLINT'
          elsif min >= -integer  && max < integer  then 'INT'
          elsif min >= -bigint   && max < bigint   then 'BIGINT'
          else
            raise ArgumentError, "min #{min} and max #{max} exceeds supported range"
          end
        end

      end # module SQL

      include SQL

      module ClassMethods
        # Types for Sqlserver databases.
        #
        # @return [Hash] types for Sqlserver databases.
        #
        # @api private
        def type_map
          length    = Property::DEFAULT_LENGTH
          precision = Property::DEFAULT_PRECISION
          scale     = Property::DEFAULT_SCALE_BIGDECIMAL

          @type_map ||= super.merge(
            DateTime    => { :primitive => 'DATETIME'                                         },
            Date        => { :primitive => 'SMALLDATETIME'                                    },
            Time        => { :primitive => 'SMALLDATETIME'                                    },
            TrueClass   => { :primitive => 'BIT',                                             },
            Types::Text => { :primitive => 'NVARCHAR', :length => 'max'                       }
          ).freeze
        end
      end # module ClassMethods
    end # module SqlserverAdapter


    module Repository
      # Determine whether a particular named storage exists in this repository
      #
      # @param [String]
      #   storage_name name of the storage to test for
      #
      # @return [Boolean]
      #   true if the data-store +storage_name+ exists
      #
      # @api semipublic
      def storage_exists?(storage_name)
        adapter = self.adapter
        if adapter.respond_to?(:storage_exists?)
          adapter.storage_exists?(storage_name)
        end
      end

      # @api semipublic
      def upgrade_model_storage(model)
        adapter = self.adapter
        if adapter.respond_to?(:upgrade_model_storage)
          adapter.upgrade_model_storage(model)
        end
      end

      # @api semipublic
      def create_model_storage(model)
        adapter = self.adapter
        if adapter.respond_to?(:create_model_storage)
          adapter.create_model_storage(model)
        end
      end

      # @api semipublic
      def destroy_model_storage(model)
        adapter = self.adapter
        if adapter.respond_to?(:destroy_model_storage)
          adapter.destroy_model_storage(model)
        end
      end

      # Destructively automigrates the data-store to match the model.
      # First migrates all models down and then up.
      # REPEAT: THIS IS DESTRUCTIVE
      #
      # @api public
      def auto_migrate!
        DataMapper.auto_migrate!(name)
      end

      # Safely migrates the data-store to match the model
      # preserving data already in the data-store
      #
      # @api public
      def auto_upgrade!
        DataMapper.auto_upgrade!(name)
      end
    end # module Repository

    module Model
      # @api private
      def self.included(mod)
        mod.descendants.each { |model| model.extend self }
      end

      # @api semipublic
      def storage_exists?(repository_name = default_repository_name)
        repository(repository_name).storage_exists?(storage_name(repository_name))
      end

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

      # Safely migrates the data-store to match the model
      # preserving data already in the data-store
      #
      # @param Symbol repository_name the repository to be migrated
      #
      # @api public
      def auto_upgrade!(repository_name = self.repository_name)
        assert_valid
        base_model = self.base_model
        if base_model == self
          repository(repository_name).upgrade_model_storage(self)
        else
          base_model.auto_upgrade!(repository_name)
        end
      end

      # Destructively migrates the data-store down, which basically
      # deletes all the models.
      # REPEAT: THIS IS DESTRUCTIVE
      #
      # @param Symbol repository_name the repository to be migrated
      #
      # @api private
      def auto_migrate_down!(repository_name = self.repository_name)
        assert_valid
        base_model = self.base_model
        if base_model == self
          repository(repository_name).destroy_model_storage(self)
        else
          base_model.auto_migrate_down!(repository_name)
        end
      end

      # Auto migrates the data-store to match the model
      #
      # @param Symbol repository_name the repository to be migrated
      #
      # @api private
      def auto_migrate_up!(repository_name = self.repository_name)
        assert_valid
        base_model = self.base_model
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
