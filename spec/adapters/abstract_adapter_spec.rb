require 'pathname'
require Pathname(__FILE__).dirname.expand_path.parent + 'spec_helper'

require __DIR__.parent.parent + 'lib/data_mapper/adapters/abstract_adapter'
require __DIR__.parent + 'adapter_shared_spec'

describe DataMapper::Adapters::AbstractAdapter do
  before do
    @adapter = DataMapper::Adapters::AbstractAdapter.new(:default, 'mock_uri_string')
  end

  it_should_behave_like 'a DataMapper Adapter'
  
  it "should raise NotImplementedError when #create is called" do
    lambda { @adapter.create(:repository, :instance) }.should raise_error(NotImplementedError)
  end
  
  it "should raise NotImplementedError when #read is called" do
    lambda { @adapter.read(:repository, :resource, [:key]) }.should raise_error(NotImplementedError)
  end
  
  it "should raise NotImplementedError when #update is called" do
    lambda { @adapter.update(:repository, :instance) }.should raise_error(NotImplementedError)
  end
  
  it "should raise NotImplementedError when #delete is called" do
    lambda { @adapter.delete(:repository, :instance) }.should raise_error(NotImplementedError)
  end
  
  it "should raise NotImplementedError when #read_one is called" do
    lambda { @adapter.read_one(:repository, :query) }.should raise_error(NotImplementedError)
  end
  
  it "should raise NotImplementedError when #read_set is called" do
    lambda { @adapter.read_set(:repository, :query) }.should raise_error(NotImplementedError)
  end
  
  it "should raise NotImplementedError when #delete_set is called" do
    lambda { @adapter.delete_set(:repository, :query) }.should raise_error(NotImplementedError)
  end

end
