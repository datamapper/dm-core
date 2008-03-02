require File.dirname(__FILE__) + "/spec_helper"

describe DataMapper::Model, "initialization" do
  before(:all) do
    class Developer < DataMapper::Model
      property :name, :string
    end
  end

  it "should require a property to be defined" do
    class IncompleteModel < DataMapper::Model; end

    lambda { IncompleteModel.new }.should raise_error(DataMapper::Model::IncompleteModelDefinitionError)
  end

  it "should initialize attributes (Hash)" do
    sam = Developer.new(:name => 'Sam')
    sam.name.should == 'Sam'
  end

  it "should initialize attributes (persistable)"

  it "should initialize attributes (Struct)"

  it "should new_with_attributes"

end

describe DataMapper::Container, "property definitions" do
  before(:each) do
    class Developer < DataMapper::Container; end

    @property = mock("DataMapper::Property")
    DataMapper::Property.stub!(:new).and_return(@property)
  end

  it "should make an id by default" do
    # id doesn't get caught by the stub, because its auto-created in #key
    Developer.property(:name, :string)
    Developer.properties.first.should be_kind_of(DataMapper::Property)
    Developer.properties.first.name.should eql(:id)
    Developer.properties.first.type.should eql(:integer)
  end

  # NOTE: rspec incorrectly assumes :string means expect any string. I pass it ":string" to get around this, but the
  # real method expects a symbol for type. TODO: change this when it starts accepting type classes, "String"
  it "should take a single name and type" do
    DataMapper::Property.should_receive(:new).with(Developer, :name, ":string", {}).and_return(:property_name)
    Developer.property(:name, ":string")
    Developer.properties.should include(:property_name)
  end

  it "should take a list of names, and make properties for each" do
    DataMapper::Property.should_receive(:new).with(Developer, :name, ":string", {}).and_return(:property_name)
    DataMapper::Property.should_receive(:new).with(Developer, :password, ":string", {}).and_return(:property_password)
    Developer.property(:name, :password, ":string")
    Developer.properties.should include(:property_name)
    Developer.properties.should include(:property_password)
  end

  it "should pass the options hash on to Property#new" do
    DataMapper::Property.should_receive(:new).with(Developer, :name, ":string", {:options => :hash}).and_return(:property_name)
    Developer.property(:name, ":string", :options => :hash)
    Developer.properties.should include(:property_name)
  end

  it "should return the property that gets defined" do
    DataMapper::Property.should_receive(:new).with(Developer, :name, ":string", {}).and_return(:property_name)
    Developer.property(:name, ":string").should eql(:property_name)
  end

  it "should return the multiple properties that get defined" do
    DataMapper::Property.should_receive(:new).with(Developer, :name, ":string", {}).and_return(:property_name)
    DataMapper::Property.should_receive(:new).with(Developer, :password, ":string", {}).and_return(:property_password)
    Developer.property(:name, :password, ":string").should eql([:property_name, :property_password])
  end

  after(:each) do
    Developer.instance_eval("@properties = []")
  end

end

