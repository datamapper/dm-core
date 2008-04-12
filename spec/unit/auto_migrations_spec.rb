require 'pathname'
require Pathname(__FILE__).dirname.expand_path.parent + 'spec_helper'

require ROOT_DIR + 'lib/data_mapper/repository'
require ROOT_DIR + 'lib/data_mapper/resource'
require ROOT_DIR + 'lib/data_mapper/auto_migrations'

describe "DataMapper::AutoMigrations" do

  before :all do
    DataMapper.setup(:default, "mock://localhost/mock") unless DataMapper::Repository.adapters[:default]
    DataMapper::AutoMigrations.klasses.clear
    
    @cow = Class.new do
      include DataMapper::Resource
      include DataMapper::AutoMigrations

      property :name, String, :key => true
      property :age, Fixnum
    end
  end
  
  it "should record the resource class on a mixin" do
    @class = Class.new do
      include DataMapper::Resource
      include DataMapper::AutoMigrations
    end
    
    DataMapper::AutoMigrations.klasses.should include(@class)
  end
end