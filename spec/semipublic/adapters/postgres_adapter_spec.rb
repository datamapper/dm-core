require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'spec_helper'))

dir = DataMapper.root / 'lib' / 'dm-core' / 'spec'

require dir / 'adapter_shared_spec'
require dir / 'data_objects_adapter_shared_spec'

describe 'Adapter' do
  supported_by :postgres do
    describe DataMapper::Adapters::PostgresAdapter do

      it_should_behave_like 'An Adapter'
      it_should_behave_like 'A DataObjects Adapter'

    end
  end
end
