require 'pathname'
require Pathname(__FILE__).dirname.expand_path.parent + 'spec_helper'

require ROOT_DIR + 'lib/data_mapper/property'

describe DataMapper::Type do

  before(:each) do
    class TestType < DataMapper::Type
      primitive String
      size 10
    end

    class TestType2 < DataMapper::Type
      primitive String
      size 10

      def self.load(value)
        value.reverse
      end

      def self.dump(value)
        value.reverse
      end
    end
  end

  it "should have the same PROPERTY_OPTIONS aray as DataMapper::Property" do
    # pending("currently there is no way to read PROPERTY_OPTIONS and aliases from DataMapper::Property. Also, some properties need to be defined as aliases instead of being listed in the PROPERTY_OPTIONS array")
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
    TestType.options.should == { :size => 10, :length => 10 }
  end

  it "should have length aliased to size" do
    TestType.length.should == TestType.size
  end

  it "should pass through the value if load wasn't overriden" do
    TestType.load("test").should == "test"
  end

  it "should pass through the value if dump wasn't overriden" do
    TestType.dump("test").should == "test"
  end

  it "should not raise NotImplmenetedException if load was overriden" do
    TestType2.dump("helo").should == "oleh"
  end

  it "should not raise NotImplmenetedException if dump was overriden" do
    TestType2.load("oleh").should == "helo"
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
