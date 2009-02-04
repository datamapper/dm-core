dir = Pathname(__FILE__).dirname.expand_path / 'core_ext'

require dir / 'array'
require dir / 'kernel'
require dir / 'module'
require dir / 'symbol'
