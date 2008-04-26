require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'spec_helper'))

include DataMapper::Types

describe DataMapper::Types::Flag do
  
  describe ".new" do
    it "should create a Class" do
      Flag.new.should be_instance_of(Class)
    end
    
    it "should create unique a Class each call" do
      Flag.new.should_not == Flag.new
    end
    
    it "should use the arguments as the values in the @flag_map hash" do
      Flag.new(:first, :second, :third).flag_map.values.should == [:first, :second, :third]
    end
    
    it "should create keys by the 2 power series for the @flag_map hash, staring at 1" do
      Flag.new(:one, :two, :three, :four, :five).flag_map.keys.should include(1, 2, 4, 8, 16)
    end
  end
  
  describe ".[]" do
    it "should be an alias for the new method" do
      Flag.should_receive(:new).with(:uno, :dos, :tres)
      Flag[:uno, :dos, :tres]
    end
  end
  
  describe ".dump" do
    before(:each) do
      @flag = Flag[:first, :second, :third, :fourth, :fifth]
    end
    
    it "should return the key of the value match from the flag map" do
      @flag.dump(:first).should == 1
      @flag.dump(:second).should == 2
      @flag.dump(:third).should == 4
      @flag.dump(:fourth).should == 8
      @flag.dump(:fifth).should == 16
    end
    
    it "should return a binary flag built from the key values of all matches" do
      @flag.dump(:first, :second).should == 3
      @flag.dump(:second, :fourth).should == 10
      @flag.dump(:first, :second, :third, :fourth, :fifth).should == 31
    end
    
    it "should return 0 if there is no match" do
      @flag.dump(:zero).should == 0
    end
  end
  
  describe ".load" do
    before(:each) do
      @flag = Flag[:uno, :dos, :tres, :cuatro, :cinco]
    end
    
    it "should return the value of the key match from the flag map" do
      @flag.load(1).should == [:uno]
      @flag.load(2).should == [:dos]
      @flag.load(4).should == [:tres]
      @flag.load(8).should == [:cuatro]
      @flag.load(16).should == [:cinco]
    end
    
    it "should return an array of all flags matches" do
      @flag.load(3).should include(:uno, :dos)
      @flag.load(10).should include(:dos, :cuatro)
      @flag.load(31).should include(:uno, :dos, :tres, :cuatro, :cinco)
    end
    
    it "should return an empty array if there is no key" do
      @flag.load(-1).should == []
      @flag.load(nil).should == []
      @flag.load(32).should == []
    end
  end
end
