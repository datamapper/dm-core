require 'pathname'
require Pathname(__FILE__).dirname.expand_path + 'spec_helper'

describe DataMapper::PropertySet do

  before do
    class Icon
      include DataMapper::Resource
      
      property :id, Fixnum, :serial => true
      property :name, String
      property :width, Fixnum, :lazy => true
      property :height, Fixnum, :lazy => true
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
  
end