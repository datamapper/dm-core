require File.join(File.dirname(__FILE__), 'spec_helper')

describe "Delete Command" do
  
  it "should drop and create the table" do
    repository.schema[Zoo].drop!.should == true
    repository.schema[Zoo].exists?.should == false
    repository.schema[Zoo].create!.should == true
  end
  
end
