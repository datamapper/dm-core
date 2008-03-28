require 'pathname'
require Pathname(__FILE__).dirname.expand_path + 'spec_helper'

describe DataMapper::PropertySet do

  before(:each) do
    class Icon
      include DataMapper::Resource
      
      property :id, Fixnum, :serial => true
      property :name, String
      property :width, Fixnum, :lazy => true
      property :height, Fixnum, :lazy => true
    end
    
    class Boat
      include DataMapper::Resource
      property :name, String  #not lazy
      property :text, Text    #Lazy by default
      property :notes, String, :lazy => true
      property :a1, String, :lazy => [:ctx_a,:ctx_c]
      property :a2, String, :lazy => [:ctx_a,:ctx_b]
      property :a3, String, :lazy => [:ctx_a]      
      property :b1, String, :lazy => [:ctx_b]
      property :b2, String, :lazy => [:ctx_b]
      property :b3, String, :lazy => [:ctx_b]   
    end    
    
    @properties = Icon.properties(:default)
  end
  
  it "should find properties with #select" do
    @properties.select(:name, 'width', :height).compact.should have(3).entries
    @properties.select { |property| property.type == Fixnum }.should have(3).entries
  end
  
  it "should find properties by index and name (Symbol or String)" do
    @properties[0].should == @properties.detect(:id)
    @properties[1].should == @properties.detect('name')
  end
  
  it "should provide defaults" do
    @properties.defaults.should have(2).entries
    @properties.should have(4).entries
  end
  
  
  it "should have a hash of lazy loaded properties in contexts" do 
    Boat.properties(:default).should respond_to(:lazy_loaded)
  end
  
  it 'should add a property for lazy loading  to the :default context if a context is not supplied' do
    Boat.properties(:default).lazy_loaded.context(:default).length.should == 2 # text & notes
  end  
  
  it 'should return a list of contexts that a given field is in' do
    props =  Boat.properties(:default)
    set = props.lazy_loaded.field_contexts(:a1)
    set.include?(:ctx_a).should == true
    set.include?(:ctx_c).should == true
    set.include?(:ctx_b).should == false
  end
  
  it 'should return a list of expanded fields that should be loaded with a given field' do
    props =  Boat.properties(:default)
    set = props.lazy_loaded.expand_fields(:a2)
    expect = [:a1,:a2,:a3,:b1,:b2,:b3]
    expect.each {|item| set.include?(item).should == true}
    set.include?(:text).should == false
    
    set = props.lazy_loaded.expand_fields([:a3,:b1])  # with an array of field name symbols
    expect.each {|item| set.include?(item).should == true}    
  end  
  
end
