require File.dirname(__FILE__) + "/spec_helper"

describe "DataMapper::Persistable::ConvenienceMethods::ClassMethods" do
  
  before(:all) do
    fixtures(:animals)
    fixtures(:exhibits)
  end
  
  describe 'A record' do
    it 'should save and return true if validations pass' do
      count = Exhibit.count
      bugs_and_more_bugs = Exhibit.new(:name => 'Bugs And More Bugs')
      bugs_and_more_bugs.save.should be_true
      Exhibit.count.should == count + 1
    end

    it 'should return false on save if validations fail' do
      count = Exhibit.count
      bugs_and_more_bugs = Exhibit.new
      bugs_and_more_bugs.save.should be_false
      Exhibit.count.should == count
    end

    it 'should reload its attributes' do
      frog = Animal.first(:name => 'Frog')
      frog.name = 'MegaFrog'
      frog.name.should == 'MegaFrog'
      frog.reload!
      frog.name.should == 'Frog'
    end
    
    it "should prepare it's associations for reload" do
      chippy = Animal.first(:name => 'Cup')
      amazonia = Exhibit.first(:name => 'Amazonia')
      amazonia.animals << chippy
      amazonia.animals.should include(chippy)
      amazonia.reload!
      amazonia.animals.should_not include(chippy)
    end

    it 'should be destroyed!' do
      capybara = Animal.create(:name => 'Capybara')
      count = Animal.count
      capybara.destroy!
      Animal.first(:name => 'Capybara').should be_nil
      Animal.count.should == count - 1
    end
  end

  it 'should return the first match using find_or_create' do
    count = Animal.count
    frog = Animal.find_or_create(:name => 'Frog')
    frog.name.should == 'Frog'
    Animal.count.should == count
  end

  it 'should create a record if a match is not found with find_or_create' do
    count = Animal.count
    capybara = Animal.find_or_create(:name => 'Capybara')
    capybara.name.should == 'Capybara'
    Animal.count.should == count + 1
  end

  it 'should return all records' do
    all_animals = Animal.all
    all_animals.length.should == Animal.count
    all_animals.each do |animal|
      animal.class.should == Animal
    end
  end

  it 'should return the first record' do
    Animal.first.should == Animal.find(:first)
  end

  it 'should return a count of the records' do
    Animal.count.should == Animal.find_by_sql("SELECT COUNT(*) FROM animals")[0]
  end

  it 'should delete all records' do
    Animal.delete_all
    Animal.count.should == 0

    fixtures(:animals)
  end

  #it 'should be truncated' do
  #  Animal.truncate!
  #  Animal.count.should == 0
  #
  #  fixtures(:animals)
  #end

  it 'should find a matching record given an id' do
    Animal.find(1).name.should == 'Frog'
  end

  it 'should find all records' do
    Animal.find(:all).length.should == Animal.count
  end

  it 'should find all matching records given some condition' do
    Animal.find(:all, :conditions => ["name = ?", "Frog"])[0].name.should == 'Frog'
  end

  it 'should find the first matching record' do
    Animal.find(:first).name.should == 'Frog'
  end

  it 'should find the first matching record given some condition' do
    Animal.find(:first, :conditions => ["name = ?", "Frog"]).name.should == 'Frog'
  end

  it 'should select records using the supplied sql fragment' do
    Animal.find_by_sql("SELECT name FROM animals WHERE name='Frog'")[0].should == 'Frog'
  end

  it 'should retrieve the indexed element' do
    Animal[1].id.should == 1
  end

  it 'should create a new record' do
    count = Animal.count
    capybara = Animal.create(:name => 'Capybara')
    capybara.name.should == 'Capybara'
    Animal.count.should == count + 1
  end
end


# Can't describe DataMapper::Persistable because
# rspec will include it for some crazy reason!
describe "DataMapper::Persistable" do
  
  it "should raise ObjectNotFoundError for missing objects with the indexer finder" do
    # pending "http://wm.lighthouseapp.com/projects/4819-datamapper/tickets/111-should-raise-objectnotfounderror-on-the-indexer-finder"
    lambda { Zoo[900] }.should raise_error(DataMapper::ObjectNotFoundError)
  end
  
  it "should raise IncompleteModelDefinitionError for a model with no properties" do
    lambda { class IncompleteZoo; include DataMapper::Persistable; end; IncompleteZoo.new }.should raise_error(DataMapper::Persistable::IncompleteModelDefinitionError)
  end
  
  it "attributes method should load all lazy-loaded values" do
    Animal.first(:name => 'Cup').attributes[:notes].should == 'I am a Cup!'
  end
  
  it "mass assignment should call methods" do
    class Animal
      attr_reader :test
      def test=(value)
        @test = value + '!'
      end
    end
    
    a = Animal.new(:test => 'testing')
    a.test.should == 'testing!'
  end
  
  it "should be dirty" do
    x = Person.create(:name => 'a')
    x.should_not be_dirty
    x.name = 'dslfay'
    x.should be_dirty
  end
  
  it "should be dirty when set to nil" do
    x = Person.create(:name => 'a')
    x.should_not be_dirty
    x.name = "asdfasfd"
    x.should be_dirty    
  end
  
  it "should return a diff" do
    x = Person.new(:name => 'Sam', :age => 30, :occupation => 'Programmer')
    y = Person.new(:name => 'Amy', :age => 21, :occupation => 'Programmer')
    
    diff = (x ^ y)
    diff.should include(:name)
    diff.should include(:age)
    diff[:name].should eql(['Sam', 'Amy'])
    diff[:age].should eql([30, 21])
    
    x.destroy!
    y.destroy!
  end
  
  it "should update attributes" do
    x = Person.create(:name => 'Sam')
    x.update_attributes(:age => 30).should eql(true)
    x.age.should eql(30)
    x.should_not be_dirty
  end 
  
  it "should return the table for a given model" do
    Person.table.should be_a_kind_of(DataMapper::Adapters::Sql::Mappings::Table)
  end
  
  it "should support boolean accessors" do
    dolphin = Animal.first(:name => 'Dolphin')
    dolphin.should be_nice
  end

  it "should be comparable" do
    p1 = Person.create(:name => 'Sam')
    p2 = Person[p1.id]

    p1.should == p2
  end

  # This is unnecessary. Use #dirty? to check for changes.
  # it "should not be equal if attributes have changed" do
  #   p1 = Person.create(:name => 'Sam')
  #   p2 = Person[p1.id]
  #   p2.name = "Paul"
  # 
  #   p1.should_not == p2
  # end

end

describe 'A new record' do
  
  before(:each) do
    @bob = Person.new(:name => 'Bob', :age => 30, :occupation => 'Sales')
  end
  
  it 'should be dirty' do
    @bob.dirty?.should == true
  end
  
  it 'set attributes should be dirty' do
    attributes = @bob.attributes.dup.reject { |k,v| k == :id }
    @bob.dirty_attributes.should == { :name => 'Bob', :age => 30, :occupation => 'Sales' }
  end
  
  it 'should be marked as new' do
    @bob.new_record?.should == true
  end
  
  it 'should have a nil id' do
    @bob.id.should == nil
  end
  
  it "should not have dirty attributes when not dirty" do
    x = Person.create(:name => 'a')
    x.should_not be_dirty
    x.dirty_attributes.should be_empty
  end
  
  it "should only list attributes that have changed in the dirty attributes hash" do
    x = Person.create(:name => 'a')
    x.name = "asdfr"
    x.should be_dirty
    x.dirty_attributes.keys.should == [:name]
  end
  
  it "should not have original_values when a new record" do
    x = Person.new(:name => 'a')
    x.original_values.should be_empty
  end
  
  it "should have original_values after saved" do
    x = Person.new(:name => 'a')
    x.save
    x.original_values.should_not be_empty
    x.original_values.keys.should include(:name)
    x.original_values[:name].should == 'a'
  end
  
  it "should have original values when created" do
    x = Person.create(:name => 'a')
    x.original_values.should_not be_empty
    x.original_values.keys.should include(:name)
    x.original_values[:name].should == "a"
  end
  
  it "should have original values when loaded from the database" do
    Person.create(:name => 'a')
    x = Person.first(:name => 'a')
    x.original_values.should_not be_empty
    x.original_values.keys.should include(:name)
    x.original_values[:name].should == "a"
  end
  
  it "should reset the original values when not new, changed then saved" do
    x = Person.create(:name => 'a')
    x.should_not be_new_record
    x.original_values[:name].should == "a"
    x.name = "b"
    x.save
    x.original_values[:name].should == "b"
  end
  
  it "should allow a value to be set to nil" do
    x = Person.create(:name => 'a')
    x.name = nil
    x.save
    x.reload!
    x.name.should be_nil    
  end

end

describe 'Properties' do

  it 'should default to public method visibility' do
    class SoftwareEngineer #< DataMapper::Base # please do not remove this
      include DataMapper::Persistable
      
      set_table_name 'people'
      property :name, :string
    end

    public_properties = SoftwareEngineer.public_instance_methods.select { |m| ["name", "name="].include?(m) }
    public_properties.length.should == 2
  end

  it 'should respect protected property options' do
    class SanitationEngineer #< DataMapper::Base # please do not remove this
      include DataMapper::Persistable

      set_table_name 'people'
      property :name, :string, :reader => :protected
      property :age, :integer, :writer => :protected
    end

    protected_properties = SanitationEngineer.protected_instance_methods.select { |m| ["name", "age="].include?(m) }
    protected_properties.length.should == 2
  end

  it 'should respect private property options' do
    class ElectricalEngineer #< DataMapper::Base # please do not remove this
      include DataMapper::Persistable

      set_table_name 'people'
      property :name, :string, :reader => :private
      property :age, :integer, :writer => :private
    end

    private_properties = ElectricalEngineer.private_instance_methods.select { |m| ["name", "age="].include?(m) }
    private_properties.length.should == 2
  end

  it 'should set both reader and writer visibiliy when accessor option is passed' do
    class TrainEngineer #< DataMapper::Base # please do not remove this
      include DataMapper::Persistable

      property :name, :string, :accessor => :private
    end

    private_properties = TrainEngineer.private_instance_methods.select { |m| ["name", "name="].include?(m) }
    private_properties.length.should == 2
  end

  it 'should only be listed in attributes if they have public getters' do
    class SalesEngineer #< DataMapper::Base # please do not remove this
      include DataMapper::Persistable

      set_table_name 'people'
      property :name, :string
      property :age, :integer, :reader => :private
    end

    @sam = SalesEngineer.first(:name => 'Sam')
    # note: id default key gets a public reader by default (but writer is protected)
    @sam.attributes.should == {:id => @sam.id, :name => @sam.name}
  end

  it 'should not allow mass assignment if private or protected' do
    class ChemicalEngineer #< DataMapper::Base # please do not remove this
      include DataMapper::Persistable

      set_table_name 'people'
      property :name, :string, :writer => :private
      property :age, :integer
    end

    @sam = ChemicalEngineer.first(:name => 'Sam')
    @sam.attributes = {:name => 'frank', :age => 101}
    @sam.age.should == 101
    @sam.name.should == 'Sam'
  end

  it 'should allow :protected to be passed as an alias for a public reader, protected writer' do
    class CivilEngineer #< DataMapper::Base # please do not remove this
      include DataMapper::Persistable

      set_table_name 'people'
      property :name, :string, :protected => true
    end

    CivilEngineer.public_instance_methods.should include("name")
    CivilEngineer.protected_instance_methods.should include("name=")
  end

  it 'should allow :private to be passed as an alias for a public reader, private writer' do
    class AudioEngineer #< DataMapper::Base # please do not remove this
      include DataMapper::Persistable

      set_table_name 'people'
      property :name, :string, :private => true
    end

    AudioEngineer.public_instance_methods.should include("name")
    AudioEngineer.private_instance_methods.should include("name=")
  end
  
  it 'should raise an error when invalid options are passsed' do
    lambda do
      class JumpyCow #< DataMapper::Base # please do not remove this
        include DataMapper::Persistable

        set_table_name 'animals'
        property :name, :string, :laze => true
      end
    end.should raise_error(ArgumentError)
  end

  it 'should raise an error when the first argument to index isnt an array' do
    lambda do
      class JumpyCow #< DataMapper::Base # please do not remove this
        include DataMapper::Persistable

        set_table_name 'animals'
        index :name, :parent
      end
    end.should raise_error(ArgumentError)
  end
  
  it "should return true on saving a new record" do
    bob = User.new(:name => 'bob', :email => 'bob@example.com')
    bob.save!.should == true
    bob.destroy!
  end
  
  it "should assign to public setters" do
    x = Project.new
    x.attributes = { :set_us_up_the_bomb => true }
    x.should be_set_up_for_bomb
  end
  
  it "should protect private setters" do
    x = Project.new
    x.attributes = { :be_wery_sneaky => true }
    x.should_not be_wery_sneaky
  end
  
  it "should not call initialize on materialization" do
    # pending "http://wm.lighthouseapp.com/projects/4819-datamapper/tickets/113-use-allocate-to-materialize-objects"
    x = Tomato.new
    x.should be_initialized
    x.save!
    x.name.should eql('Ugly')
    x.should be_bruised
    
    x.name = 'Bob'
    x.save!
    
    x2 = Tomato.first(:name => 'Bob')
    x2.should_not be_bruised
    x2.heal!
    x2.should == x
    x2.name.should eql('Bob')
    x2.should_not be_initialized
    
    x3 = Tomato.get(x.key)
    x3.should_not be_bruised
    x3.heal!
    x3.should == x
    x3.name.should eql('Bob')
    x3.should_not be_initialized
  end
  
  it "should report persistable" do
    Tomato.should be_persistable
  end
end
