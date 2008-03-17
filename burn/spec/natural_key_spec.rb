require File.join(File.dirname(__FILE__), 'spec_helper')

describe('A Natural Key') do
  
  it "should cause the Table to return a default foreign key composed of it's table and key column name" do
    repository.table(Person).default_foreign_key.should eql('person_id')
    repository.table(Career).default_foreign_key.should eql('career_name')
  end
  
  it "should load the object based on it's natural key" do
    programmer = Career['Programmer']
    programmer.should_not be_nil
    programmer.name.should eql('Programmer')
    programmer.attributes.should include(:name)
  end
  
  it "should load an association based on the natural key" do
    repository do
      programmer = Career['Programmer']
      programmer.followers.should have(2).entries
      
      sam = Person.first(:name => 'Sam')
      scott = Person.first(:name => 'Scott')
      
      programmer.followers.should include(sam)
      programmer.followers.should include(scott)
      
      peon = Career['Peon']
      peon.followers.should have(1).entries
      
      bob = Person.first(:name => 'Bob')
      peon.followers.should include(bob)
    end
  end
  
end
