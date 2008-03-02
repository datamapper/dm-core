require File.dirname(__FILE__) + "/spec_helper"

describe('Multiple Databases') do
  
  it "should scope model creation and lookup" do
    repository(:secondary) do
      Zoo.create :name => 'secondary'
    end
    
    Zoo.first(:name => 'secondary').should be_nil
    
    repository(:secondary) do
      Zoo.first(:name => 'secondary').should_not be_nil
      Zoo.first(:name => 'secondary').destroy!
    end
  end
  
end
