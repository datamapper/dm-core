dir = Pathname(__FILE__).dirname.expand_path / 'types'

require dir / 'boolean'
require dir / 'discriminator'
require dir / 'text'
require dir / 'paranoid_datetime'
require dir / 'paranoid_boolean'

module DataMapper
  module Resource
    include Types
  end # module Resource
end # module DataMapper
