require File.join(File.dirname(__FILE__), 'spec_helper')

describe 'Single Table Inheritance' do
  
  before(:all) do
    fixtures(:people)
  end
  
  it "should save and load the correct Type" do
    repository do
      ted = SalesPerson.new(:name => 'Ted')
      ted.save
    
      clone = Person.first(:name => 'Ted')
      ted.should == clone
      
      clone.class.should eql(SalesPerson)      
    end
    
    # Since we're not executing within the same database context
    # this is not the same object instance as the previous ones.
    clone2 = Person.first(:name => 'Ted')
    
    clone2.class.should eql(SalesPerson)    
  end
  
  it "secondary database should inherit the same attributes" do
    
    repository(:mock) do |db|
      db.table(SalesPerson)[:name].should_not be_nil
    end
    
  end
  
  it "should inherit the callbacks of the parent class" do
    repository do      
      adam = SalesPerson.new(:name => 'adam')
      adam.save
      adam.reload.notes.should eql("Lorem ipsum dolor sit amet")
    end
  end
  
end
