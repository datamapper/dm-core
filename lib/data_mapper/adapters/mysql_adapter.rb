require 'data_mapper/adapters/data_object_adapter'
begin
  require 'do_mysql'
rescue LoadError
  STDERR.puts <<-EOS
You must install the DataObjects::Mysql driver.
  gem install do_mysql
EOS
  exit
end

module DataMapper
  module Adapters
    
    class MysqlAdapter < DataObjectAdapter
      
      TRUE_ALIASES << "T".freeze << "\004\bT".freeze
      FALSE_ALIASES << "F".freeze << "\004\bF".freeze
      
      def empty_insert_sql
        "() VALUES ()"
      end
      
      def create_connection
        
        connection_string = ""
        builder = lambda { |k,v| connection_string << "#{k}=#{@configuration.send(v)} " unless @configuration.send(v).blank? }
        
        builder['host', :host]
        builder['user', :username]
        builder['password', :password]
        builder['dbname', :database]
        builder['socket', :socket]
        builder['port', :port]
        
        logger.debug { connection_string.strip }
        
        conn = DataObject::Mysql::Connection.new(connection_string.strip)
        conn.logger = self.logger
        conn.open
        cmd = conn.create_command("SET NAMES UTF8")
        cmd.execute_non_query
        return conn
      end
      
      def database_column_name
        "TABLE_SCHEMA"
      end
      
      module Mappings
        
        def to_create_table_sql
          @to_create_table_sql || @to_create_table_sql = begin
            "CREATE TABLE #{to_sql} (#{columns.map { |c| c.to_long_form }.join(', ')}) Type=MyISAM CHARACTER SET utf8"
          end
        end
        
        class Schema

          def database_tables
            get_database_tables(@adapter.schema.name)
          end

        end

        
      end # module Mappings
    end # class MysqlAdapter
    
  end # module Adapters
end # module DataMapper