dir = Pathname(__FILE__).dirname.expand_path / 'adapters'

require dir / 'abstract_adapter'
require dir / 'data_objects_adapter'
require dir / 'sqlite3_adapter'
require dir / 'mysql_adapter'
require dir / 'postgres_adapter'
