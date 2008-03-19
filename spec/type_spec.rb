require __DIR__ + 'spec_helper'
require __DIR__.parent + 'lib/data_mapper/property'

describe DataMapper::Type do

  before(:each) do
    class TestType < DataMapper::Type
      primitive String
      size 10
    end
  end
  
  it "should have the same PROPERTY_OPTIONS aray as DataMapper::Property" do
    DataMapper::Type::PROPERTY_OPTIONS.should == DataMapper::Property::PROPERTY_OPTIONS
  end
  
  it "should create a new type based on String primitive" do
    TestType.primitive.should == String
  end
  
  it "should have size of 10" do
    TestType.size.should == 10
  end
  
  it "should have options hash exactly equal to options specified in custom type" do
    #ie. it should not include null elements
    TestType.options.should == { :size => 10 }
  end
  
  it "should have length aliased to size" do
    TestType.length.should == TestType.size
  end

end