require 'pathname'
require Pathname(__FILE__).dirname.expand_path.parent + 'spec_helper'

require ROOT_DIR + 'lib/data_mapper/repository'
require ROOT_DIR + 'lib/data_mapper/resource'
require ROOT_DIR + 'lib/data_mapper/auto_migrations'

describe DataMapper::AutoMigrations do

  before :all do
    DataMapper.setup(:default, "mock://localhost/mock") unless DataMapper::Repository.adapters[:default]
    DataMapper::AutoMigrator.models.clear
    
    @cow = Class.new do
      include DataMapper::Resource
      include DataMapper::AutoMigrations

      property :name, String, :key => true
      property :age, Fixnum
    end
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
end