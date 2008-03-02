$:.unshift(File.dirname(__FILE__))
require File.dirname(__FILE__) + "/../lib/data_mapper/resource"

describe DataMapper::Resource do
  
  before(:all) do
    DataMapper.setup(:default, "mock://localhost/mock") unless DataMapper::Repository[:default]
    DataMapper.setup(:legacy, "mock://localhost/mock") unless DataMapper::Repository[:legacy]
    DataMapper.setup(:yet_another_repository, "mock://localhost/mock") unless DataMapper::Repository[:yet_another_repository]
    
    class Planet
      include DataMapper::Resource
      
      resource_names[:legacy] = "dying_planets"
      
      has :name, String
      has :age, Fixnum
    end
  end
  
  it "should provide a resource_name" do
    Planet.should respond_to(:resource_name)
    Planet.resource_name(:default).should == 'planets'
    Planet.resource_name(:legacy).should == 'dying_planets'
  end
  
  it "should provide properties" do
    Planet.properties(:default).should have(2).entries
  end
  
  it "should provide mapping defaults" do
    Planet.resource_name(:yet_another_repository) == 'planets'
    Planet.properties(:yet_another_repository).should have(2).entries
  end
  
end