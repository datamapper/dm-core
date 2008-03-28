require File.dirname(__FILE__) + '/../spec_helper'

include DataMapper::Types

describe DataMapper::Types::Enum do
  
  describe ".new" do
    it "should create a Class" do
      Enum.new.should be_instance_of(Class)
    end
    
    it "should create unique a Class each call" do
      Enum.new.should_not == Enum.new
    end
    
    it "should use the arguments as the values in the @flag_map hash" do
      Enum.new(:first, :second, :third).flag_map.values.should == [:first, :second, :third]
    end
    
    it "should create incremental keys for the @flag_map hash, staring at 1" do
      Enum.new(:one, :two, :three, :four).flag_map.keys.should == (1..4).to_a
    end
  end
  
  describe ".[]" do
    it "should be an alias for the new method" do
      Enum.should_receive(:new).with(:uno, :dos, :tres)
      Enum[:uno, :dos, :tres]
    end
  end
  
  describe ".dump" do
    before(:each) do
      @enum = Enum[:first, :second, :third]
    end
    
    it "should return the key of the value match from the flag map" do
      @enum.dump(:first).should == 1
      @enum.dump(:second).should == 2
      @enum.dump(:third).should == 3
    end
    
    it "should return nil if there is no match" do
      @enum.dump(:zero).should be_nil
    end
  end
  
  describe ".load" do
    before(:each) do
      @enum = Enum[:uno, :dos, :tres]
    end
    
    it "should return the value of the key match from the flag map" do
      @enum.load(1).should == :uno
      @enum.load(2).should == :dos
      @enum.load(3).should == :tres
    end
    
    it "should return nil if there is no key" do
      @enum.load(-1).should be_nil
    end
  end
end