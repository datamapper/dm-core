require File.dirname(__FILE__) + "/spec_helper"

describe Validatable::ValidatesUniquenessOf do
  
  before(:all) do 
    fixtures('people')
  end
  
  it 'must have a unique name' do
    class Animal
      validations.clear
      validates_uniqueness_of :name, :event => :save
    end
    
    bugaboo = Animal.new
    bugaboo.valid?.should == true

    bugaboo.name = 'Bear'
    bugaboo.valid?(:save).should == false
    bugaboo.errors.full_messages.first.should == 'Name has already been taken'

    bugaboo.name = 'Bugaboo'
    bugaboo.valid?(:save).should == true
  end
  
  it 'must have a unique name for their occupation' do
    class Person
      validations.clear
      validates_uniqueness_of :name, :event => :save, :scope => :occupation
    end
    
    new_programmer_scott = Person.new(:name => 'Scott', :age => 29, :occupation => 'Programmer')
    garbage_man_scott = Person.new(:name => 'Scott', :age => 25, :occupation => 'Garbage Man')
    
    # Should be valid even though there is another 'Scott' already in the database
    garbage_man_scott.valid?(:save).should == true

    # Should NOT be valid, there is already a Programmer names Scott, adding one more
    # would destroy the universe or something
    new_programmer_scott.valid?(:save).should == false
    new_programmer_scott.errors.full_messages.first.should == "Name has already been taken"
  end

  it 'must have a unique name for their occupation and career_name' do
    class Person
      validations.clear
      validates_uniqueness_of :name, :event => :save, :scope => [:occupation, :career_name]
    end
    
    new_programmer_scott = Person.new(:name => 'Scott', :age => 29, :occupation => 'Programmer', :career_name => 'Programmer')
    junior_programmer_scott = Person.new(:name => 'Scott', :age => 25, :occupation => 'Programmer', :career_name => 'Junior Programmer')
    
    # Should be valid even though there is another 'Scott' already in the database
    junior_programmer_scott.valid?(:save).should == true

    # Should NOT be valid, there is already a Programmer names Scott, adding one more
    # would destroy the universe or something
    new_programmer_scott.valid?(:save).should == false
    new_programmer_scott.errors.full_messages.first.should == "Name has already been taken"
  end
  
  it "should allow custom error messages" do
    class Animal
      validations.clear
      validates_uniqueness_of :name, :event => :save, :message => 'You try to steal my name? I kill you!'
    end
    
    bugaboo = Animal.new
    bugaboo.valid?.should == true

    bugaboo.name = 'Bear'
    bugaboo.valid?(:save).should == false
    bugaboo.errors.full_messages.first.should == 'You try to steal my name? I kill you!'
  end
  
  it "should not interfere with the destruction of an object" do
    pending "see: http://wm.lighthouseapp.com/projects/4819-datamapper/tickets/139"
    
    ## creating two dups so that we have invalid records in the db
    Project.create(:title => 'Dup')
    Project.create(:title => 'Dup')
    
    class Project
      validations.clear
      validates_uniqueness_of :title, :message => 'You try to steal my title? I kill you!'
    end
    
    project = Project.first(:title => 'Dup')
    project.destroy!.should == true
    
  end
end
