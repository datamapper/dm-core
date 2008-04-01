require __DIR__ + 'data_objects_adapter'
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
    
    class PostgresAdapter < DataObjectsAdapter
      
      def create_with_returning?; true; end
      
    end # class PostgresqlAdapter
    
  end # module Adapters
end # module DataMapper
