require File.join(File.dirname(__FILE__), '..', 'lib', 'data_mapper', 'resource')
require File.join(File.dirname(__FILE__), 'mock_adapter')

# rSpec completely FUBARs everything if you give it a Module here.
# So we give it a String of the module name instead.
# DO NOT CHANGE THIS!
describe "DataMapper::Resource" do
  
  before(:all) do
    
    DataMapper.setup(:default, "mock://localhost/mock") unless DataMapper::Repository.adapters[:default]
    DataMapper.setup(:legacy, "mock://localhost/mock") unless DataMapper::Repository.adapters[:legacy]
    DataMapper.setup(:yet_another_repository, "mock://localhost/mock") unless DataMapper::Repository.adapters[:yet_another_repository]
    
    class Planet
      
      include DataMapper::Resource
      
      resource_names[:legacy] = "dying_planets"
      
      property :name, String
      property :age, Fixnum
      property :core, String, :private => true
      
      # repository(:legacy) do
      #   property :name, String
      # end
    end
  end
  
  it "should provide a resource_name" do
    Planet.new respond_to(:resource_name)
    Planet.resource_name(:default).should == 'planets'
    Planet.resource_name(:legacy).should == 'dying_planets'
  end
  
  it "should provide properties" do
    Planet.properties(:default).should have(3).entries
  end
  
  it "should provide mapping defaults" do
    Planet.resource_name(:yet_another_repository) == 'planets'
    Planet.properties(:yet_another_repository).should have(3).entries
  end
  
  it "should have attributes" do
    attributes = { :name => 'Jupiter', :age => 1_000_000, :core => nil }
    jupiter = Planet.new(attributes)
    jupiter.attributes.should == attributes
  end
  
  it "should be able to set attributes (including private attributes)" do
    attributes = { :name => 'Jupiter', :age => 1_000_000, :core => nil }
    jupiter = Planet.new(attributes)
    jupiter.attributes.should == attributes
    jupiter.attributes = attributes.merge({ :core => 'Magma' })
    jupiter.attributes.should == attributes
    jupiter.send(:private_attributes=, attributes.merge({ :core => 'Magma' }))
    jupiter.attributes.should == attributes.merge({ :core => 'Magma' })
  end
  
  it "should provide a repository" do
    Planet.repository.name.should == :default
  end

  it "should not mark properties loaded until values submitted" do
    attributes = { :name => 'Jupiter', :age => 1_000_000 }
    jupiter = Planet.new(attributes)
    jupiter.class.properties(:default)[:name].loaded?.should == true
    jupiter.class.properties(:default)[:core].loaded?.should == false
    jupiter.send(:private_attributes=, attributes.merge({ :core => 'Magma' }))
    jupiter.class.properties(:default)[:core].loaded?.should == true
  end

  it "should not mark properties dirty until values submitted" do
    attributes = { :name => 'Jupiter', :age => 1_000_000 }
    jupiter = Planet.new(attributes)
    jupiter.class.properties(:default)[:name].dirty?.should == false
    jupiter.name = 'jupiter'
    jupiter.class.properties(:default)[:name].dirty?.should == true
    jupiter.class.properties(:default)[:core].dirty?.should == false
    jupiter.send(:private_attributes=, attributes.merge({ :core => 'Magma' }))
    jupiter.class.properties(:default)[:core].dirty?.should == false
    jupiter.send(:private_attributes=, attributes.merge({ :core => 'magma' }))
    jupiter.class.properties(:default)[:core].dirty?.should == true
  end
end
