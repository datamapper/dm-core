require File.join(File.dirname(__FILE__), 'spec_helper')

describe "Save Commands" do
  
  before(:all) do
    fixtures(:zoos)
  end
  
  it "should create a new row" do
    total = Zoo.all.length
    Zoo.create({ :name => 'bob' })
    zoo = Zoo.first(:name => 'bob')
    zoo.name.should == 'bob'
    Zoo.all.length.should == total+1
  end
  
  it "should update an existing row" do
    dallas = Zoo.first(:name => 'Dallas')
    dallas.name = 'bob'
    dallas.save
    dallas.name = 'Dallas'
    dallas.save
  end
  
  it "should be able to read other attributes after a record is created" do
    zoo = Zoo.create({ :name => 'bob' })
    zoo.notes.should == nil
  end
  
  it "should stamp association on save" do
    repository do
      dallas = Zoo.first(:name => 'Dallas')
      dallas.exhibits << Exhibit.new(:name => 'Flying Monkeys')
      dallas.save
      Exhibit.first(:name => 'Flying Monkeys').zoo.should == dallas
    end
  end
  
  it "should return success of save call, not status of query execution" do
    # pending "http://wm.lighthouseapp.com/projects/4819/tickets/54-save-should-return-success"
    Exhibit.first.save.should be_true
  end
  
  it "should be invalid if invalid associations are loaded" do
    miami = Zoo.first(:name => 'Miami')
    fish_fancy = Exhibit.new
    miami.exhibits << fish_fancy
    miami.should_not be_valid
    fish_fancy.name = 'Fish Fancy'
    fish_fancy.should be_valid
    miami.should be_valid
  end
  
  it "should retrieve it's id on creation if the key is auto-incrementing so it can be successively updated" do
    repository do # Use the same Session so the reference-equality checks will pass.
      mary = Animal::create(:name => 'Mary')
      mary.name = 'Jane'
      # Without retrieving the id during creation, the following #save call would fail,
      # because we wouldn't know what id to update.
      mary.save.should == true
      jane = Animal.first(:name => 'Jane')
      mary.should == jane
    end
  end
  
  it "should not be dirty if there are no attributes to update" do
    bob = Animal.new
    bob.should_not be_dirty
    bob.name = 'bob'
    bob.dirty_attributes.should == { :name => 'bob' }
    bob.should be_dirty
  end
  
  it "should not persist invalid objects" do
    zoo = Zoo.create(:notes => "I'm invalid!")
    zoo.should_not be_valid
    zoo.should be_new_record
  end
  
  it "should create a Project with a \"Main\" Section" do
    repository do
      project = Project::create(:title => 'Test')
      project.sections.first.should == Section.first
      project.sections.first.should be_a_kind_of(Section)
    end
  end
  
  it "save! should raise an error if validation failed" do
    # pending "http://wm.lighthouseapp.com/projects/4819/tickets/29-dm-context-write"
    empty = Zoo.new
    lambda { empty.save! }.should raise_error(DataMapper::ValidationError)
  end
  
end
