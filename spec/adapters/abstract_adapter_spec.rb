require 'pathname'
require Pathname(__FILE__).dirname.expand_path.parent + 'spec_helper'

require __DIR__.parent.parent + 'lib/data_mapper/adapters/abstract_adapter'
require __DIR__.parent + 'adapter_sharedspec'

describe DataMapper::Adapters::AbstractAdapter do
  before do
    @adapter = DataMapper::Adapters::AbstractAdapter.new('mock_uri_string')
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
    lambda { @adapter.create(:repository, :query) }.should raise_error(NotImplementedError)
  end
  
  it "should raise NotImplementedError when #delete_one is called" do
    lambda { @adapter.create(:repository, :query) }.should raise_error(NotImplementedError)
  end
  
  it "should raise NotImplementedError when #delete_set is called" do
    lambda { @adapter.create(:repository, :query) }.should raise_error(NotImplementedError)
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

  # Deprecated in favor of AbstractAdapter#read_one(repository, query)
  # describe '#first' do
  #   it 'should raise an argument error if a limit was set in the query' do
  #     lambda { @adapter.first(:repository, Class, :limit => 10) }.should raise_error(ArgumentError)
  #   end
  # 
  #   it 'should pass all query options + :limit to #read_set' do
  #     @adapter.should_receive(:read_set) { |repo, klass, query|
  #       repo.should  == :repository
  #       klass.should == Class
  #       query.should be_kind_of(Hash)
  #       query.should have_key(:limit)
  #       query[:limit].should == 1
  #       query.should have_key(:custom)
  #       query[:custom].should == :opts
  # 
  #       [:first_record]
  #     }
  # 
  #     @adapter.first(:repository, Class, {:custom => :opts}).should == :first_record
  #   end
  # end

end
