dir = Pathname(__FILE__).dirname.expand_path / 'core_ext'

require dir / 'array'
#require dir / 'kernel'  # must require explicitly
#require dir / 'symbol'  # must require explicitly
