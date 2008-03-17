require File.join(File.dirname(__FILE__), '../../lib/data_mapper/adapters/data_object_adapter')
require File.join(File.dirname(__FILE__), '..', 'adapter_sharedspec')

describe DataMapper::Adapters::DataObjectAdapter do
  before do
    @adapter = DataMapper::Adapters::DataObjectAdapter.new('mock::/localhost')
  end

  it_should_behave_like 'a DataMapper Adapter'

end
