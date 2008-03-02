require File.dirname(__FILE__) + "/../spec_helper"

describe "Kernel#silence_warnings" do
  
  it "should not warn" do
    $VERBOSE.should_not be_nil
    
    silence_warnings do
      $VERBOSE.should be_nil
    end
    
    $VERBOSE.should_not be_nil
  end
  
end