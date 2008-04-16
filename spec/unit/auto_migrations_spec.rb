require 'pathname'
require Pathname(__FILE__).dirname.expand_path.parent + 'spec_helper'

require ROOT_DIR + 'lib/data_mapper/repository'
require ROOT_DIR + 'lib/data_mapper/resource'
require ROOT_DIR + 'lib/data_mapper/auto_migrations'

describe DataMapper::AutoMigrations do

  before :all do
    DataMapper.setup(:default, "mock://localhost/mock") unless DataMapper::Repository.adapters[:default]
    
    @cow = Class.new do
      include DataMapper::Resource
      include DataMapper::AutoMigrations

      property :name, String, :key => true
      property :age, Fixnum
    end
  end
  
  before(:each) do
    DataMapper::AutoMigrator.models.clear
  end
  
  after(:each) do
    DataMapper::AutoMigrator.models.clear
  end
  
  it "should add the resource class to AutoMigrator's models on a mixin" do
    @class = Class.new do
      include DataMapper::Resource
      include DataMapper::AutoMigrations
    end
    
    DataMapper::AutoMigrator.models.should include(@class)
  end
  
  it "should not conflict with Migrator's models on a mixin" do
    migrator_class = Class.new(DataMapper::Migrator)
    
    included_proc = lambda { |model| migrator_class.models << model }
    
    migrator_mixin = Module.new do
      self.class.send(:define_method, :included, &included_proc)
    end
    
    model_class = Class.new do
      include DataMapper::Resource
      include DataMapper::AutoMigrations
      include migrator_mixin
      
      property :name, String
      property :age, String
    end
    
    DataMapper::AutoMigrator.models.should include(model_class)
    migrator_class.models.should include(model_class)
  end
  
  describe "#auto_migrate" do
    before(:each) do
      @repository = mock(:repository)
      @adapter = mock(:adapter)
      @repository.stub!(:adapter).and_return(@adapter)
    end
    
    it "should call the repository's adapter's #destroy_object_store and #create_object_store method with each model" do
      models = [:cat, :dog, :fish, :cow]
      
      models.each do |model|
        DataMapper::AutoMigrator.models << model
        @adapter.should_receive(:destroy_object_store).with(model)
        @adapter.should_receive(:create_object_store).with(model)
      end
      
      DataMapper::AutoMigrator.auto_migrate(@repository)
    end
  end
end