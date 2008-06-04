dir = Pathname(__FILE__).dirname.expand_path / 'adapters'

require dir / 'abstract_adapter'
require dir / 'data_objects_adapter'
