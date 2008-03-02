require File.dirname(__FILE__) + '/table'
    
module DataMapper
  module Adapters
    module Sql
      module Mappings
    
        class Schema
    
          attr_reader :name
          
          def initialize(adapter, database_name)
            @name = database_name
            @adapter = adapter
            @tables = Hash.new { |h,k| h[k] = adapter.class::Mappings::Table.new(@adapter, k) }
          end
          
          def [](klass)
            @tables[klass]
          end
      
          def each
            @tables.values.each do |table|
              yield table
            end
          end
          
          def delete(table)
            @tables.delete(table.name)
          end
          
          def <<(table)
            @tables[table.name] = table
          end

          def to_tables_sql
            @to_column_exists_sql || @to_column_exists_sql = <<-EOS.compress_lines
              SELECT TABLE_NAME
              FROM INFORMATION_SCHEMA.TABLES
              WHERE TABLE_SCHEMA LIKE ?
            EOS
          end
          
          def get_database_tables(schema = "%")
            tables = []            
            @adapter.connection do |db|
              command = db.create_command(to_tables_sql)
              command.execute_reader(schema) do |reader|
                tables = reader.map { @adapter.class::Mappings::Table.new(@adapter, reader.item(0)) }
              end
            end
            tables
          end
    
        end
    
      end
    end
  end
end