require __DIR__ + 'data_object_adapter'
begin
  require "do_postgres"
rescue LoadError
  STDERR.puts <<-EOS
You must install the DataObjects::Postgres driver.
  gem install do_postgres
EOS
  exit
end

module DataMapper
  module Adapters
    
    class PostgresqlAdapter < DataObjectAdapter
      
      def schema_search_path
        @schema_search_path || @schema_search_path = begin
          if @configuration.schema_search_path
            @configuration.schema_search_path.split(',').map do |part|
              part.blank? ? nil : part.strip.ensure_wrapped_with("'")
            end.compact
          else
            []
          end
        end
      end
      
      def create_connection
        connection_string = ""
        builder = lambda do |k,v|
          connection_string << "#{k}=#{@configuration.send(v)} " unless
            @configuration.send(v).blank?
        end
        builder["host",     :host]
        builder["user",     :username]
        builder["password", :password]
        builder["dbname",   :database]
        builder["socket",   :socket]
        builder["port",     :port]
        conn = DataObject::Postgres::Connection.new(connection_string.strip)
        conn.logger = self.logger
        conn.open

        unless schema_search_path.empty?
          execute("SET search_path TO #{schema_search_path}")
        end

        return conn
      end
      
      def database_column_name
        "TABLE_CATALOG"
      end
            
      TABLE_QUOTING_CHARACTER = '"'.freeze
      COLUMN_QUOTING_CHARACTER = '"'.freeze
      
      TYPES.merge!({
        :integer => "integer".freeze,
        :datetime => "timestamp with time zone".freeze
      })
        
      module Mappings
        class Table
          def sequence_sql
            @sequence_sql ||= quote_table("_id_seq").freeze
          end
          
          def to_create_table_sql
            schema_name = name.index('.') ? name.split('.').first : nil
            schema_list = @adapter.query('SELECT nspname FROM pg_namespace').join(',')
          
            sql = if schema_name and !schema_list.include?(schema_name)
                "CREATE SCHEMA #{@adapter.quote_table_name(schema_name)}; " 
            else
              ''
            end
            
            sql << "CREATE TABLE " << to_sql
          
            sql << " (" << columns.map do |column|
              column.to_long_form
            end.join(', ') << ")"
          
            return sql
          end
          
          # The logic of this comes from AR; it was modified for smarter typecasting
          def unquote_default(default)
            # Boolean types
            return true if default =~ /true/i
            return false if default =~ /false/i

            # Char/String/Bytea type values
            return $1 if default =~ /^'(.*)'::(bpchar|text|character varying|bytea)$/

            # Numeric values
            return value.to_f if default =~ /^-?[0-9]+(\.[0-9]*)/
            return value.to_i if default =~ /^-?[0-9]+/

            # Fixed dates / times
            return Date.parse($1) if default =~ /^'(.+)'::date/
            return DateTime.parse($1) if default =~ /^'(.+)'::timestamp/            

            # Anything else is blank, some user type, or some function
            # and we can't know the value of that, so return nil.
            return nil       
          end
          
          # def to_exists_sql
          #   @to_exists_sql || @to_exists_sql = <<-EOS.compress_lines
          #     SELECT TABLE_NAME
          #     FROM INFORMATION_SCHEMA.TABLES
          #     WHERE TABLE_NAME = ?
          #       AND TABLE_CATALOG = ?
          #   EOS
          # end
          # 
          # def to_column_exists_sql
          #   @to_column_exists_sql || @to_column_exists_sql = <<-EOS.compress_lines
          #     SELECT TABLE_NAME, COLUMN_NAME
          #     FROM INFORMATION_SCHEMA.COLUMNS
          #     WHERE TABLE_NAME = ?
          #     AND COLUMN_NAME = ?
          #     AND TABLE_CATALOG = ?
          #   EOS
          # end          
                    
          private 
          
          def quote_table(table_suffix = nil)
            parts = name.split('.')
            parts.last << table_suffix if table_suffix
            parts.map { |part|
              @adapter.quote_table_name(part) }.join('.')
          end
        end # class Table
        
        class Schema
          
          def database_tables
            get_database_tables("public")
          end
          
        end
        
        class Column
          def serial_declaration
            "SERIAL"
          end
          
          def check_declaration
          	"CHECK (" << check << ")"
          end
          
          def to_alter_sql
            "ALTER TABLE " <<  table.to_sql << " ALTER COLUMN " << to_alter_form
          end
          
          def alter!
            result = super
            reset_alter_state!
            result
          end
          
          def reset_alter_state!
            @type_changed = false
            @default_changed = false
          end
          
          def default=(value)
            @default_changed = true
            super
          end
          
          def type=(value)
            @type_changed = true
            super
          end
          
          def to_alter_form
            sql = to_sql.dup
            
            changes = 0
            
            if @type_changed
              changes += 1
              sql << " TYPE " << type_declaration
              case self.type
              when :integer then sql << " USING #{to_sql}::integer"
              when :datetime then
                sql << " USING timestamp with time zone"
              end
            end
            
            if @default_changed
              sql << ", " if changes += 1 > 1
              
              if default.blank? || default_declaration.blank?
                sql << " DROP DEFAULT"
              else
                sql << " " << default_declaration
              end
            end
            
            sql
          end
          
          def to_long_form
            @to_long_form || begin
              @to_long_form = "#{to_sql}"
              
              if serial? && !serial_declaration.blank?
                @to_long_form << " #{serial_declaration}"
                if key? && !primary_key_declaration.blank?
                  @to_long_form << " #{primary_key_declaration}"
                end
              else
                @to_long_form << " #{type_declaration}"
                
                unless nullable? || not_null_declaration.blank?
                  @to_long_form << " #{not_null_declaration}"
                end
                
                if default && !default_declaration.blank?
                  @to_long_form << " #{default_declaration}"
                end
                
                if unique? && !unique_declaration.blank?
                  @to_long_form << " #{unique_declaration}"
                end
                
                if check && !check_declaration.blank?
                  @to_long_form << " #{check_declaration}"
                end
              end
                      
              @to_long_form
            end
          end
          
          # size is still required, as length in postgres behaves slightly differently
          def size
            case self.type
            #strings in postgres can be unlimited length
            when :string then return (@options.has_key?(:length) || @options.has_key?(:size) ? @size : nil)
            else nil
            end
          end
        end # class Column
      end # module Mappings
      
    end # class PostgresqlAdapter
    
  end # module Adapters
end # module DataMapper
