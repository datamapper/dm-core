dir = Pathname(__FILE__).dirname.expand_path / 'adapters'

require dir / 'abstract_adapter'
require dir / 'data_objects_adapter'
begin
  require dir / 'sqlite3_adapter'
rescue LoadError
  # ignore it
end
begin
  require dir / 'mysql_adapter'
rescue LoadError
  # ignore it
end
begin
  require dir / 'postgres_adapter'
rescue LoadError
  # ignore it
end
