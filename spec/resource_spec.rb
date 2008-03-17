require Pathname(__FILE__).dirname.parent + 'lib/data_mapper/resource'
require Pathname(__FILE__).dirname + 'mock_adapter'

# rSpec completely FUBARs everything if you give it a Module here.
# So we give it a String of the module name instead.
# DO NOT CHANGE THIS!
describe "DataMapper::Resource" do
  
  before(:all) do
    
    DataMapper.setup(:default, "mock://localhost/mock") unless DataMapper::Repository.adapters[:default]
    DataMapper.setup(:legacy, "mock://localhost/mock") unless DataMapper::Repository.adapters[:legacy]
    
    unless DataMapper::Repository.adapters[:yet_another_repository]
      adapter = DataMapper.setup(:yet_another_repository, "mock://localhost/mock")
      adapter.resource_naming_convention = DataMapper::NamingConventions::Underscored
    end
    
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
    Planet.resource_name(:yet_another_repository).should == 'planet'
  end
  
  it "should provide properties" do
    Planet.properties(:default).should have(3).entries
  end
  
  it "should provide mapping defaults" do
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
end
