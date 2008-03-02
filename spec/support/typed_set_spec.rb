require File.dirname(__FILE__) + "/../spec_helper"

describe DataMapper::Support::TypedSet do
  
  it "should accept objects of a defined type, and raise for others" do

    s = DataMapper::Support::TypedSet.new(Zoo, Animal)

    lambda do
      s << Zoo.new
      s.size.should == 1
    end.should_not raise_error(ArgumentError)

    lambda do
      s << Animal.new
      s.size.should == 2
    end.should_not raise_error(ArgumentError)

    lambda do
      s << Exhibit.new
      s.size.should == 2
    end.should raise_error(ArgumentError)

  end

  it "should be sorted" do

    s = DataMapper::Support::TypedSet.new(Numeric)

    s << 8
    s << 4
    s << 9
    s << 27
    s << 30
    s << 1
    s << 0
    s << 5
    s << 3

    s.entries.first.should eql(0)
    s.entries.last.should eql(30)
  end

  it "should respond to blank?" do
    s = DataMapper::Support::TypedSet.new(Numeric)
    s.should be_blank

    s << 4
    s.should_not be_blank
  end

  it "should return the combined entries for two sets" do
    a = DataMapper::Support::TypedSet.new(Numeric)
    b = DataMapper::Support::TypedSet.new(Numeric)

    a << 1 << 2 << 3
    b << 4 << 5 << 6 << 3

    c = (a + b)
    c.should have(6).entries
    c.entries.should == [ 1, 2, 3, 4, 5, 6 ]

    lambda { (c + nil) }.should_not raise_error
  end

end