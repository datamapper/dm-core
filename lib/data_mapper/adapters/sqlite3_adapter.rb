require File.join(File.dirname(__FILE__), 'data_object_adapter')

begin
  require 'do_sqlite3'
rescue LoadError
  STDERR.puts <<-EOS
You must install the DataObjects::SQLite3 driver.
  gem install do_sqlite3
EOS
  exit
end

module DataMapper
  module Adapters
    
    class Sqlite3Adapter < DataObjectAdapter
      
      TYPES.merge!({
        :integer => 'INTEGER'.freeze,
        :string => 'TEXT'.freeze,
        :text => 'TEXT'.freeze,
        :class => 'TEXT'.freeze,
        :boolean => 'INTEGER'.freeze
      })

      TABLE_QUOTING_CHARACTER = '"'.freeze
      COLUMN_QUOTING_CHARACTER = '"'.freeze
      
      def create_connection
        connnection = DataObjects::Sqlite3::Connection.new(@uri)
        # connnection.logger = DataMapper.logger
        return connnection
      end
      
      def batch_insertable?
        false
      end
      
      module Mappings
                
        class Table
          def to_exists_sql
            @to_exists_sql || @to_exists_sql = <<-EOS.compress_lines
              SELECT "name"
              FROM "#{temporary? ? 'sqlite_temp_master' : 'sqlite_master'}"
              WHERE "type" = "table"
                AND "name" = ?
            EOS
          end
          
          def to_column_exists_sql
            @to_column_exists_sql || @to_column_exists_sql = <<-EOS.compress_lines
              PRAGMA TABLE_INFO(?)
            EOS
          end
          
          def to_truncate_sql
            "DELETE FROM #{to_sql}"
          end
          
          alias_method :to_columns_sql, :to_column_exists_sql
          
          def unquote_default(default)
            default.gsub(/(^'|'$)/, "") rescue default
          end
          
        end # class Table
        
        class Column
          def serial_declaration
            "AUTOINCREMENT"
          end
          
          def size
            nil
          end
                    
          def alter!
            @adapter.connection do |db|
              flush_sql_caches!
              backup_table = @adapter.table("#{@table.name}_backup")

              @table.columns.each do |column|
                backup_table.add_column(column.name, column.type, column.options)
              end

              backup_table.temporary = true

              backup_table.create!
              
              sql = <<-EOS.compress_lines
                INSERT INTO #{backup_table.to_sql} SELECT #{@table.columns.map { |c| c.to_sql }.join(', ')} FROM #{@table.to_sql};
                DROP TABLE #{@table.to_sql};
                #{@table.to_create_sql};
                INSERT INTO #{@table.to_sql} SELECT #{backup_table.columns.map { |c| c.to_sql }.join(', ')} FROM #{backup_table.to_sql};
              EOS
              
              sql.split(';').each do |part|
                db.create_command(part).execute_non_query
              end
              
              backup_table.drop!
              flush_sql_caches!
            end
          end
          
          def drop!
            @adapter.connection do |db|
              @table.columns.delete(self)
              flush_sql_caches!
              
              backup_table = @adapter.table("#{@table.name}_backup")
              
              @table.columns.each do |column|
                backup_table.add_column(column.name, column.type, column.options)
              end

              backup_table.temporary = true

              backup_table.create!
              
              sql = <<-EOS.compress_lines
                INSERT INTO #{backup_table.to_sql} SELECT #{@table.columns.map { |c| c.to_sql }.join(', ')} FROM #{@table.to_sql};
                DROP TABLE #{@table.to_sql};
                #{@table.to_create_sql};
                INSERT INTO #{@table.to_sql} SELECT #{backup_table.columns.map { |c| c.to_sql }.join(', ')} FROM #{backup_table.to_sql};
              EOS
              
              sql.split(';').each do |part|
                db.create_command(part).execute_non_query
              end
              
              backup_table.drop!
              flush_sql_caches!
            end
          end          
          
        end # class Column
      end # module Mappings
      
    end # class Sqlite3Adapter
    
  end # module Adapters
end # module DataMapper