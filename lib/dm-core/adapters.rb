dir = Pathname(__FILE__).dirname.expand_path / 'adapters'

require dir / 'abstract_adapter'
require dir / 'in_memory_adapter'

def try_loading(adapter)
  begin
    require adapter
  rescue LoadError
    # Ignore it
  end
end

# TODO Factor these out into dm-more

%w[
  data_objects_adapter
  sqlite3_adapter
  mysql_adapter
  postgres_adapter
].each do |adapter|
  try_loading(dir / adapter)
end
