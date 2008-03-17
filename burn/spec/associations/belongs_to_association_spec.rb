require File.join(File.dirname(__FILE__), '..', 'spec_helper')

describe DataMapper::Associations::BelongsToAssociation do
  before(:all) do
    fixtures(:zoos)
  end

  before(:each) do
    @aviary = Exhibit.first(:name => 'Monkey Mayhem')
  end

  it "should provide a shallow_append method that doesn't impact the complementary association" do
    project = Project.new
    section = Section.new
    section.send(:project_association).shallow_append(project)
    project.sections.should be_empty
  end

  it 'has a zoo association' do
    @aviary.zoo.class.should == Zoo
    Exhibit.new.zoo.should == nil
  end

  it 'belongs to a zoo' do
    @aviary.zoo.should == @aviary.database_context.first(Zoo, :name => 'San Diego')
  end

  it "is assigned a zoo_id" do
    zoo = Zoo.first
    exhibit = Exhibit.new(:name => 'bob')
    exhibit.zoo = zoo
    exhibit.instance_variable_get("@zoo_id").should == zoo.id

    exhibit.save.should eql(true)

    zoo2 = Zoo.first
    zoo2.exhibits.should include(exhibit)

    exhibit.destroy!

    zoo = Zoo.new(:name => 'bob')
    bob = Exhibit.new(:name => 'bob')
    zoo.exhibits << bob
    zoo.save.should eql(true)

    zoo.exhibits.first.should_not be_a_new_record

    bob.destroy!
    zoo.destroy!
  end

  it "should not assign zoo_id when passed nil" do
    # pending "http://wm.lighthouseapp.com/projects/4819-datamapper/tickets/147"
    exhibit = Exhibit.first
    exhibit.zoo_id = nil
    exhibit.zoo_id.should be_nil
    exhibit.save.should == true

    exhibit.reload
    exhibit.zoo_id.should be_nil
    exhibit.zoo.should be_nil
  end

  it "should be marked dirty if the complementary association is a new_record and the instance is already saved" do
    zoo = Zoo.new(:name => "My Zoo")
    tiger = Exhibit.create(:name => "Tiger")
    zoo.exhibits << tiger
    tiger.should be_dirty
  end

  it 'can build its zoo' do
    repository do |db|
      e = Exhibit.new({:name => 'Super Extra Crazy Monkey Cage'})
      e.zoo.should == nil
      e.build_zoo({:name => 'Monkey Zoo'})
      e.zoo.class == Zoo
      e.zoo.new_record?.should == true

      e.save
    end
  end

  it 'can build its zoo' do
    repository do |db|
      e = Exhibit.new({:name => 'Super Extra Crazy Monkey Cage'})
      e.zoo.should == nil
      e.create_zoo({:name => 'Monkey Zoo'})
      e.zoo.class == Zoo
      e.zoo.new_record?.should == false
      e.save
    end
  end

  after(:all) do
    fixtures('zoos')
    fixtures('exhibits')
  end
end
