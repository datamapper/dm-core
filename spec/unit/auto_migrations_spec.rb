require 'pathname'
require Pathname(__FILE__).dirname.expand_path.parent + 'spec_helper'

require DataMapper.root / 'lib' / 'data_mapper' / 'repository'
require DataMapper.root / 'lib' / 'data_mapper' / 'resource'
require DataMapper.root / 'lib' / 'data_mapper' / 'auto_migrations'

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
  
  it "should add the #auto_migrate! method on a mixin" do
    @cat = Class.new do
      include DataMapper::Resource
      include DataMapper::AutoMigrations

      property :name, String, :key => true
      property :age, Fixnum
    end
    
    @cat.should respond_to(:auto_migrate!)
  end
  
  it "should not conflict with other Migrators on a mixin" do
    migrator_class = Class.new(DataMapper::Migrator)
    
    included_proc = lambda { |model| migrator_class.models << model }
    
    migrator_mixin = Module.new do
      self.class.send(:define_method, :included, &included_proc)
    end
    
    model_class = Class.new do
      include DataMapper::Resource
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
    
    it "should call each model's auto_migrate! method" do
      models = [:cat, :dog, :fish, :cow].map {|m| mock(m)}
      
      models.each do |model|
        DataMapper::AutoMigrator.models << model
        model.should_receive(:auto_migrate!)
      end
      
      DataMapper::AutoMigrator.auto_migrate(@repository)
    end
  end
end