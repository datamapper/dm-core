require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'spec_helper'))
require DataMapper.root / 'lib' / 'dm-core' / 'spec' / 'adapter_shared_spec'

describe 'Adapter' do
  supported_by :yaml do
    describe DataMapper::Adapters::YamlAdapter do

      it_should_behave_like 'An Adapter'

    end
  end
end
