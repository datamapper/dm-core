require 'pathname'
require Pathname(__FILE__).dirname.expand_path + 'spec_helper'

describe DataMapper::Repository do

  before do
    @adapter = DataMapper::Repository.adapters[:repository_spec] || DataMapper.setup(:repository_spec, 'mock://localhost')
    
    class Vegetable
      include DataMapper::Resource
      
      property :id, Fixnum, :serial => true
      property :name, String
      
    end
  end
  
  it "should provide persistance methods" do
    repository.should respond_to(:get)
    repository.should respond_to(:first)
    repository.should respond_to(:all)
    repository.should respond_to(:save)
    repository.should respond_to(:destroy)
  end

  it 'should call #create when #save is called on a new record' do
    repository = repository(:repository_spec)
    instance = Vegetable.new({:id => 1, :name => 'Potato'})
    
    @adapter.should_receive(:create).with(repository, instance).and_return(instance)

    repository.save(instance)
  end

  it 'should call #update when #save is called on an existing record' do
    repository = repository(:repository_spec)
    instance = Vegetable.new(:name => 'Potato')
    instance.instance_variable_set('@new_record', false)
    
    @adapter.should_receive(:update).with(repository, instance).and_return(instance)

    repository.save(instance)
  end
  
end
