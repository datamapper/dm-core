require 'pathname'
require Pathname(__FILE__).dirname.expand_path.parent + 'spec_helper'

describe DataMapper::TypeMap do
  
  before(:each) do
    @tm = DataMapper::TypeMap.new
  end
  
  it "should translate a type mapped to :varchar as {:primative => :varchar}" do
    @tm.translate(DataMapper::TypeMap::TypeChain.new.to(:varchar)).should == {:primitive => :varchar}
  end
  
  it "should translate a type mapped to :varchar with :size => 100 as {:primitive => :varchar, :size => 100}" do
    @tm.translate(DataMapper::TypeMap::TypeChain.new.to(:varchar).with(:size => 100)).should == {:primitive => :varchar, :size => 100}
  end
  
  it "should translate a type with size => 100 as {:size => 100}" do
    @tm.translate(DataMapper::TypeMap::TypeChain.new.with(:size => 100)).should == {:size => 100}
  end
  
  describe "#lookup" do
    it "should raise an exception if the type is not mapped and does not have a primitive" do
      lambda { @tm.lookup(Class.new) }.should raise_error
    end
    
    it "should the primitive's mapping the class has a primitive type" do
      @tm.map(Fixnum).to(:int)
      
      lambda { @tm.lookup(DM::Enum) }.should_not raise_error
    end
    
    it "should merge in the parent type map's translated match" do
      @tm.map(String).to(:varchar)
      
      child = DataMapper::TypeMap.new(@tm)
      child.map(String).with(:size => 100)
      
      child.lookup(String).should == {:primitive => :varchar, :size => 100}
    end
  end
  
  describe "#map" do
    it "should create a new TypeChain if there is no match" do
      @tm.chains.should_not have_key(String)
      
      DataMapper::TypeMap::TypeChain.should_receive(:new)
      
      @tm.map(String)
    end
    
    it "should not create a new TypeChain if there is a match" do
      @tm.map(String)
      
      DataMapper::TypeMap::TypeChain.should_not_receive(:new)
      
      @tm.map(String)
    end
  end
  
end