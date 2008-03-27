require File.join(File.dirname(__FILE__), 'spec_helper')
require __DIR__.parent + 'lib/data_mapper/property'

describe DataMapper::Type do

  before(:each) do
    class TestType < DataMapper::Type
      primitive String
      size 10
    end
    
    class TestType2 < DataMapper::Type
      primitive String
      size 10
      
      def self.materialize(value)
        value
      end
      
      def self.serialize(value)
        value
      end
    end
  end
  
  it "should have the same PROPERTY_OPTIONS aray as DataMapper::Property" do
    pending("currently there is no way to read PROPERTY_OPTIONS and aliases from DataMapper::Property. Also, some properties need to be defined as aliases instead of being listed in the PROPERTY_OPTIONS array") do
      DataMapper::Type::PROPERTY_OPTIONS.should == DataMapper::Property::PROPERTY_OPTIONS
    end
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
  
  it "should raise NotImplmenetedException if serialize wasn't overriden" do
    lambda { TestType.serialize("test") }.should raise_error(NotImplementedError)
  end
  
  it "should raise NotImplmenetedException if materialize wasn't overriden" do
    lambda { TestType.materialize("test") }.should raise_error(NotImplementedError)
  end

  it "should not raise NotImplmenetedException if serialize was overriden" do
    TestType2.serialize("test").should == "test"
  end
  
  it "should not raise NotImplmenetedException if materialize was overriden" do
    TestType2.materialize("test").should == "test"
  end

  describe "using def Type" do
    before do
      @class = Class.new(DataMapper::Type(String, :size => 20))
    end

    it "should be of the specified type" do
      @class.primitive.should == String
    end

    it "should have the right options set" do
      @class.size.should == 20
    end
  end
end
