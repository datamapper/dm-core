require File.join(File.dirname(__FILE__), '..', 'spec_helper')

describe DataMapper::Associations::HasAndBelongsToManyAssociation do

  before(:all) do
    fixtures(:animals)
    fixtures(:exhibits)
  end

  before(:each) do
    @amazonia = Exhibit.first :name => 'Amazonia'
  end

  it "should generate the SQL for a join statement" do
    animals_association = repository(:mock).schema[Exhibit].associations.find { |a| a.name == :animals }

    animals_association.to_sql.should == <<-EOS.compress_lines
      JOIN `animals_exhibits` ON `animals_exhibits`.`exhibit_id` = `exhibits`.`id`
      JOIN `animals` ON `animals`.`id` = `animals_exhibits`.`animal_id`
    EOS
  end

  it "should load associations" do
    repository do
      froggy = Animal.first(:name => 'Frog')
      froggy.exhibits.size.should == 1
      froggy.exhibits.first.should == Exhibit.first(:name => 'Amazonia')
    end
  end

  it 'has an animals association' do
    [@amazonia, Exhibit.new].each do |exhibit|
      exhibit.animals.class.should == DataMapper::Associations::HasAndBelongsToManyAssociation::Set
    end
  end

  it 'has many animals' do
    @amazonia.animals.size.should == 1
  end

  it 'should load associations magically' do
    Exhibit.all.each do |exhibit|
      exhibit.animals.each do |animal|
        animal.exhibits.should include(exhibit)
      end
    end
  end

  it 'should allow association of additional objects' do
    buffalo = Animal.create(:name => "Buffalo")
    @amazonia.animals << buffalo
    @amazonia.animals.size.should == 2
    @amazonia.save!
    @amazonia.reload!
    @amazonia.animals.should have(2).entries

    other = Exhibit[@amazonia.id]
    other.animals.should have(2).entries

    @amazonia.animals.delete(buffalo).should_not be_nil
    @amazonia.animals.should be_dirty
    @amazonia.save!

    other = Exhibit[@amazonia.id]
    other.animals.should have(1).entries
  end

  it "should allow association of additional objects (CLEAN)" do
    # pending "http://wm.lighthouseapp.com/projects/4819-datamapper/tickets/92"

    ted = Exhibit.create(:name => 'Ted')
    ted.should_not be_dirty

    zest = Animal.create(:name => 'Zest')
    zest.should_not be_dirty

    ted.animals << zest
    ted.should be_dirty
    ted.save

    ted.reload!
    ted.should_not be_dirty
    ted.should have(1).animals

    ted2 = Exhibit[ted.key]
    ted2.should_not be_dirty
    ted2.should have(1).animals

    ted2.destroy!
    zest.destroy!
  end

  it 'should allow you to fill and clear an association' do
    marcy = Exhibit.create(:name => 'marcy')

    Animal.all.each do |animal|
      marcy.animals << animal
    end

    marcy.save.should eql(true)
    marcy.should have(Animal.count).animals

    marcy.animals.clear
    marcy.should have(0).animals

    marcy.save.should eql(true)

    marcys_stand_in = Exhibit[marcy.id]
    marcys_stand_in.should have(0).animals

    marcy.destroy!
  end

  it 'should allow you to delete a specific association member' do
    walter = Exhibit.create(:name => 'walter')

    Animal.all.each do |animal|
      walter.animals << animal
    end

    walter.save.should eql(true)
    walter.should have(Animal.count).animals

    delete_me = walter.animals.first
    walter.animals.delete(delete_me).should eql(delete_me)
    walter.animals.delete(delete_me).should eql(nil)

    walter.should have(Animal.count - 1).animals
    walter.save.should eql(true)

    walters_stand_in = Exhibit[walter.id]
    walters_stand_in.animals.size.should eql(walter.animals.size)

    walter.destroy!
  end

  it "should allow updates to associations using association_keys=" do
    # pending "http://wm.lighthouseapp.com/projects/4819-datamapper/tickets/109-associations-should-support-association_keys-methods"
    repository(:default) do
      meerkat = Animal.create(:name => "Meerkat")
      dunes = Exhibit.create(:name => "Dunes")


      dunes.animals.should be_empty
      dunes.send(:animals_keys=, meerkat.key)
      dunes.save.should be_true

      dunes.should have(1).animals
      dunes.animals.should include(meerkat)

      dunes.reload!
      dunes.should have(1).animals

      dunes.destroy!
      meerkat.destroy!
    end
  end

  it "should allow you to 'append' multiple associated objects at once" do
    dunes = Exhibit.create(:name => 'Dunes')

    lambda { dunes.animals << @amazonia.animals }.should_not raise_error(ArgumentError)
    lambda { dunes.animals << Animal.all }.should_not raise_error(ArgumentError)

    dunes.destroy!
  end

  it "should raise an error when attempting to associate an object not of the correct type (assuming added model doesn't inherit from the correct type)" do
    # pending("see: http://wm.lighthouseapp.com/projects/4819-datamapper/tickets/91")
    @amazonia.animals.should_not be_empty
    chuck = Person.new(:name => "Chuck")

    ## InvalidRecord isn't the error we should use here....needs to be changed
    lambda { @amazonia.animals << chuck }.should raise_error(ArgumentError)

  end

  it "should associate an object which has inherited from the correct type into an association" do
    # pending("see: http://wm.lighthouseapp.com/projects/4819-datamapper/tickets/91")
    programmer = Career.first(:name => 'Programmer')
    programmer.followers.should_not be_empty

    sales_person = SalesPerson.new(:name => 'Chuck')

    lambda { programmer.followers << sales_person }.should_not raise_error(ArgumentError)

  end

  it "should correctly handle dependent associations ~cascading destroy~ (:destroy)" do
    class Chain
      has_and_belongs_to_many :chains, :dependent => :destroy
    end
    Chain.auto_migrate!

    chain = Chain.create(:name => "1")
    chain.chains << Chain.create(:name => "2")
    chain.chains << Chain.create(:name => "3")
    chain.chains << Chain.create(:name => "4")
    chain.save
    chain4 = Chain.create(:name => "5")
    chain.chains.first.chains << chain4
    chain.chains.first.save
    chain4.chains << Chain.first(:name => "3")
    chain4.save
    chain = Chain[chain.key]

    chain.destroy!
    Chain.first(:name => "2").should be_nil
    Chain.first(:name => "3").should be_nil
    Chain.first(:name => "4").should be_nil
    Chain.first(:name => "5").should be_nil

    Chain.delete_all
  end

  it "should correctly handle dependent associations ~no cascade~ (:delete)" do
    class Chain
      has_and_belongs_to_many :chains, :dependent => :delete
    end
    Chain.auto_migrate!

    chain = Chain.create(:name => "1")
    chain.chains << Chain.create(:name => "2")
    chain.chains << Chain.create(:name => "3")
    chain.chains << Chain.create(:name => "4")
    chain.save
    chain5 = Chain.create(:name => "5")
    chain.chains.first.chains << chain5
    chain.chains.first.save
    chain = Chain[chain.key]

    chain.destroy!
    Chain.first(:name => "2").should be_nil
    Chain.first(:name => "3").should be_nil
    Chain.first(:name => "4").should be_nil
    Chain.first(:name => "5").should_not be_nil

    Chain.delete_all
  end

  it "should correctly handle dependent associations (:protect)" do
    class Chain
      has_and_belongs_to_many :chains, :dependent => :protect
    end
    Chain.auto_migrate!

    chain = Chain.create(:name => "1")
    chain.chains << Chain.create(:name => "2")
    chain.chains << Chain.create(:name => "3")
    chain.chains << Chain.create(:name => "4")
    chain.save
    chain4 = Chain.create(:name => "5")
    chain.chains.first.chains << chain4
    chain.chains.first.save
    chain = Chain[chain.key]

    lambda { chain.destroy! }.should raise_error(DataMapper::AssociationProtectedError)

    Chain.delete_all
  end

  it "should throw AssociationProtectedError even when @items have not been loaded yet (:protect)" do
    class Chain
      has_and_belongs_to_many :chains, :dependent => :protect
    end
    Chain.auto_migrate!

    chain = Chain.create(:name => "1")
    chain.chains << Chain.create(:name => "2")
    chain.chains << Chain.create(:name => "3")
    chain.chains << Chain.create(:name => "4")
    chain.save
    chain4 = Chain.create(:name => "5")
    chain.chains.first.chains << chain4
    chain.chains.first.save
    chain = Chain[chain.key]

    lambda { chain.destroy! }.should raise_error(DataMapper::AssociationProtectedError)

    Chain.delete_all
  end

  it "should correctly handle dependent associations (:nullify)" do
    class Chain
      has_and_belongs_to_many :chains, :dependent => :nullify
    end
    Chain.auto_migrate!

    chain = Chain.create(:name => "1")
    chain.chains << Chain.create(:name => "2")
    chain.chains << Chain.create(:name => "3")
    chain.chains << Chain.create(:name => "4")
    chain.save
    chain4 = Chain.create(:name => "5")
    chain.chains.first.chains << chain4
    chain.chains.first.save
    chain = Chain[chain.key]

    chain.destroy!
    Chain.first(:name => "2").should_not be_nil
    Chain.first(:name => "3").should_not be_nil
    Chain.first(:name => "4").should_not be_nil

    Chain.delete_all
  end

end

describe DataMapper::Associations::HasAndBelongsToManyAssociation, "self-referential relationship" do

  before(:all) do
    fixtures(:tasks)
  end

  before(:each) do
    @task_relax = Task.first(:name => "task_relax")
  end

  it "should allow a self-referential habtm by creating a related_* column for the right foreign key" do
    tasks_assocation = repository(:mock).schema[Task].associations.find { |a| a.name == :tasks }

    tasks_assocation.right_foreign_key.name.should == :related_task_id
  end

  it "should load the self-referential association" do
    repository do
      task_relax = Task.first(:name => "task_relax")
      task_relax.tasks.size.should == 1
      task_relax.tasks.first.should == Task.first(:name => "task_drink_heartily")
    end
  end

  it "should allow a mirrored relationship between two rows (no infinite recursion)" do
    task_vacation = Task.first(:name => "task_vacation")

    @task_relax.tasks << task_vacation
    @task_relax.save

    task_vacation.tasks << @task_relax
    task_vacation.save

    @task_relax.reload!
    @task_relax.tasks.should include(task_vacation)

    task_vacation.reload!
    task_vacation.tasks.should include(@task_relax)
  end

end

describe DataMapper::Associations::HasAndBelongsToManyAssociation, "compatibility with belongs_to" do

  it "should be able to save a job without interferring with applications" do
    programmer = Job.create(:name => 'Programmer')
    manager = Job.create(:name => 'Manager')

    bob = Candidate.create(:name => 'Bob')

    bob.applications << programmer << manager

    bob.applications.should have(2).entries
    bob.job.should be_nil

    bob.job = programmer

    bob.should be_dirty
    bob.applications.should be_dirty
    bob.job.should_not be_dirty # Because no property is changed on the has_many side.

    bob.save!.should == true

    impostor = Candidate[bob.id]

    impostor.applications.should have(2).entries
    impostor.job.should == programmer
  end
end
