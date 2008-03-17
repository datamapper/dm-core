
require File.join(File.dirname(__FILE__), '../../lib/data_mapper/adapters/abstract_adapter')
require File.join(File.dirname(__FILE__), '../adapter_sharedspec')

describe DataMapper::Adapters::AbstractAdapter do
  before do
    @adapter = DataMapper::Adapters::AbstractAdapter.new('mock_uri_string')
  end

  it_should_behave_like 'a DataMapper Adapter'

  %w{create read update delete}.each do |meth|
    it "should raise NotImplementedError when #{meth} is called" do
      lambda { @adapter.send(meth.intern, nil, nil) }.should raise_error(NotImplementedError)
    end
  end

  it 'should call #create when #save is called on a new record' do
    instance = mock("Model", :"new_record?" => true)
    @adapter.should_receive(:create).with(:repository, instance)

    @adapter.save(:repository, instance)
  end

  it 'should call #update when #save is called on an existing record' do
    instance = mock("Model", :"new_record?" => false)
    @adapter.should_receive(:update).with(:repository, instance)

    @adapter.save(:repository, instance)
  end

end
