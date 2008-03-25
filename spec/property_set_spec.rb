require 'pathname'
require Pathname(__FILE__).dirname.expand_path + 'spec_helper'

describe DataMapper::PropertySet do

  before do
    class Icon
      include DataMapper::Resource
      
      property :id, Fixnum, :serial => true
      property :name, String
      property :width, Fixnum
      property :height, Fixnum
    end
    
    @properties = Icon.properties(:default)
  end
  
  it "should find properties with #select" do
    @properties.select(:name, 'width', :height, 0).compact.should have(4).entries
    @properties.select { |property| property.type == Fixnum }.should have(3).entries
  end
  
  it "should find properties by index and name (Symbol or String)" do
    @properties[0].should == @properties[:id]
    @properties[1].should == @properties['name']
  end
  
end