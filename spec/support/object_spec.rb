require Pathname(__FILE__).dirname.parent + 'spec_helper'

describe DataMapper::Support::Object do
  
  it "should be able to get a recursive constant" do
    Object.recursive_const_get('DataMapper::Support::String').should == DataMapper::Support::String
  end
  
end
