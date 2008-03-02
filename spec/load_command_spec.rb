require File.dirname(__FILE__) + "/spec_helper"

describe DataMapper::Adapters::Sql::Commands::LoadCommand do
  
  def conditions_for(klass, options = {})
    database_context = repository(:mock)
    DataMapper::Adapters::Sql::Commands::LoadCommand.new(
      database_context.adapter, database_context, klass, options
    ).conditions
  end
  
  it 'empty? should be false if conditions are present' do
    conditions_for(Zoo, :name => 'Galveston').should_not be_empty
  end
  
  it 'should map implicit option names to field names' do
    conditions_for(Zoo, :name => 'Galveston').should eql([["`name` = ?", 'Galveston']])
  end
  
  it 'should qualify with table name when using a join' do
    conditions_for(Zoo, :name => 'Galveston', :include => :exhibits).should eql([["`zoos`.`name` = ?", 'Galveston']])
  end
  
  it 'should use Symbol::Operator to determine operator' do
    conditions_for(Person, :age.gt => 28).should eql([["`age` > ?", 28]])
    conditions_for(Person, :age.gte => 28).should eql([["`age` >= ?", 28]])
    
    conditions_for(Person, :age.lt => 28).should eql([["`age` < ?", 28]])
    conditions_for(Person, :age.lte => 28).should eql([["`age` <= ?", 28]])
    
    conditions_for(Person, :age.not => 28).should eql([["`age` <> ?", 28]])
    conditions_for(Person, :age.eql => 28).should eql([["`age` = ?", 28]])
    
    conditions_for(Person, :name.like => 'S%').should eql([["`name` LIKE ?", 'S%']])
    
    conditions_for(Person, :age.in => [ 28, 29 ]).should eql([["`age` IN ?", [ 28, 29 ]]])
  end
  
  it 'should use an IN clause for an Array' do
    conditions_for(Person, :age => [ 28, 29 ]).should eql([["`age` IN ?", [ 28, 29 ]]])
  end
  
  it 'should use "not" for not-equal operations' do
    conditions_for(Person, :name.not => 'Bob').should eql([["`name` <> ?", 'Bob']])
    conditions_for(Person, :name.not => nil).should eql([["`name` IS NOT ?", nil]])
    conditions_for(Person, :name.not => ['Sam', 'Bob']).should eql([["`name` NOT IN ?", ['Sam', 'Bob']]])
  end

end

describe DataMapper::Adapters::Sql::Commands::LoadCommand do
  
  before(:all) do
    fixtures(:zoos)
    fixtures(:animals)
    fixtures(:people)
  end
  
  after(:all) do
    fixtures(:people)
  end
  
  def loader_for(klass, options = {})
    database_context = repository(:mock)
    DataMapper::Adapters::Sql::Commands::LoadCommand.new(database_context.adapter, database_context, klass, options)
  end
  
  it "should return a Struct for custom queries" do
    results = repository.query("SELECT * FROM zoos WHERE name = ?", 'Galveston')
    zoo = results.first
    zoo.class.superclass.should == Struct
    zoo.name.should == "Galveston"
  end

  it "should return a simple select statement for a given class" do
    loader_for(Zoo).to_parameterized_sql.first.should == 'SELECT `id`, `name`, `updated_at` FROM `zoos`'
  end

  it "should include only the columns specified in the statement" do
    loader_for(Zoo, :select => [:name]).to_parameterized_sql.first.should == 'SELECT `name` FROM `zoos`'
  end

  it "should optionally include lazy-loaded columns in the statement" do
    loader_for(Zoo, :include => :notes).to_parameterized_sql.first.should == 'SELECT `id`, `name`, `updated_at`, `notes` FROM `zoos`'
  end

  it "should join associations in the statement" do
    loader_for(Zoo, :include => :exhibits).to_parameterized_sql.first.should == <<-EOS.compress_lines
      SELECT `zoos`.`id`, `zoos`.`name`, `zoos`.`updated_at`,
        `exhibits`.`id`, `exhibits`.`name`, `exhibits`.`zoo_id`
      FROM `zoos`
      JOIN `exhibits` ON `exhibits`.`zoo_id` = `zoos`.`id`
    EOS
  end

  it "should join has and belongs to many associtions in the statement" do
    loader_for(Animal, :include => :exhibits).to_parameterized_sql.first.should == <<-EOS.compress_lines
      SELECT `animals`.`id`, `animals`.`name`, `animals`.`nice`,
        `exhibits`.`id`, `exhibits`.`name`, `exhibits`.`zoo_id`,
        `animals_exhibits`.`animal_id`, `animals_exhibits`.`exhibit_id`
      FROM `animals`
      JOIN `animals_exhibits` ON `animals_exhibits`.`animal_id` = `animals`.`id`
      JOIN `exhibits` ON `exhibits`.`id` = `animals_exhibits`.`exhibit_id`
    EOS
  end
  
  it "should shallow-join unmapped tables for has-and-belongs-to-many in the statement" do
    loader_for(Animal, :shallow_include => :exhibits).to_parameterized_sql.first.should == <<-EOS.compress_lines
      SELECT `animals`.`id`, `animals`.`name`, `animals`.`nice`,
        `animals_exhibits`.`animal_id`, `animals_exhibits`.`exhibit_id`
      FROM `animals`
      JOIN `animals_exhibits` ON `animals_exhibits`.`animal_id` = `animals`.`id`
    EOS
  end
  
  it "should allow multiple implicit conditions" do
    expected_sql = <<-EOS.compress_lines
      SELECT `id`, `name`, `age`, `occupation`,
        `type`, `street`, `city`, `state`, `zip_code`
      FROM `people`
      WHERE (`name` = ?) AND (`age` = ?)
    EOS
    
    # NOTE: I'm actually not sure how to test this since the order of the parameters isn't gauranteed.
    # Maybe an ugly OrderedHash passed as the options...
    # loader_for(Person, :name => 'Sam', :age => 29).to_parameterized_sql.should == [expected_sql, 'Sam', 29]
  end
  
  it "should allow block-interception during load" do
    result = false
    Person.first(:intercept_load => lambda { result = true })
    result.should == true
  end
  
  it 'database-specific load should not fail' do

     DataMapper::repository do |db|
       froggy = db.first(Animal, :conditions => ['name = ?', 'Frog'])
       froggy.name.should == 'Frog'
     end

   end

   it 'current-database load should not fail' do
     froggy = DataMapper::repository.first(Animal).name.should == 'Frog'
   end

   it 'load through ActiveRecord impersonation should not fail' do
     Animal.find(:all).size.should == 16
   end

   it 'load through Og impersonation should not fail' do
     Animal.all.size.should == 16
   end

   it ':conditions option should accept a hash' do
     Animal.all(:conditions => { :name => 'Frog' }).size.should == 1
   end

   it 'non-standard options should be considered part of the conditions' do
     repository.logger.debug { 'non-standard options should be considered part of the conditions' }
     zebra = Animal.first(:name => 'Zebra')
     zebra.name.should == 'Zebra'

     elephant = Animal.first(:name => 'Elephant')
     elephant.name.should == 'Elephant'

     aged = Person.all(:age => 29)
     aged.size.should == 2
     aged.first.name.should == 'Sam'
     aged.last.name.should == 'Bob'

     fixtures(:animals)
   end

   it 'should not find deleted objects' do
     repository do
       wally = Animal.first(:name => 'Whale')
       wally.new_record?.should == false
       wally.destroy!.should == true

       wallys_evil_twin = Animal.first(:name => 'Whale')
       wallys_evil_twin.should == nil

       wally.new_record?.should == true
       wally.save
       wally.new_record?.should == false

       Animal.first(:name => 'Whale').should == wally
     end
   end

   it 'lazy-loads should issue for whole sets' do
     people = Person.all

     people.each do |person|
       person.notes
     end
   end

   it "should only query once" do
     repository do
       zoo = Zoo.first
       same_zoo = Zoo[zoo.id]
       
       zoo.should == same_zoo
     end
   end
   
   it "should return a single object" do
     Zoo.first.should be_a_kind_of(Zoo)
     Zoo[1].should be_a_kind_of(Zoo)
     Zoo.find(1).should be_a_kind_of(Zoo)
   end
   
   # TICKET: http://wm.lighthouseapp.com/projects/4819-datamapper/tickets/90
   it "should return a CLEAN object" do
     Animal[2].should_not be_dirty
     Animal.first(:name => 'Cup').should_not be_dirty
   end
   
   it "should retrieve altered integer columns correctly" do
     pending "see http://wm.lighthouseapp.com/projects/4819-datamapper/tickets/95"
     sam = Person.first
     sam.age = 6471561394
     sam.save
     sam.reload
     sam.original_values[:age].should == 6471561394
     sam.age.should == 6471561394
   end
   
   it "should be able to search on UTF-8 strings" do
     Zoo.create(:name => 'Danish Vowels: Smoot!') # øø
     Zoo.first(:name.like => '%Smoot%').should be_a_kind_of(Zoo)
   end
   
   it "should destructively reload the loaded attributes of an object" do
     zoo = Zoo.first(:name => 'Dallas')
     zoo.name.should eql('Dallas')
     zoo.name = 'bob'
     zoo.name.should eql('bob')
     zoo.reload!
     zoo.name.should eql('Dallas')
   end
   
   # See the comment in dataobjects_spec for why this is failing
   unless ENV["ADAPTER"] == "mysql"
     it "should return nil when finding by id, and the id is not present and/or invalid" do
       Zoo.find(nil).should be_nil
     end
  end
   
   # it "should return in order" do
   #   pending("This spec is silly, and nothing but trouble since it depends on the table's clustered index. :-p")
   #   fixtures(:posts)
   #        
   #   one = Post.first
   #   one.title.should eql('One')
   #   two = one.next
   #   two.title.should eql('Two')
   #   one.next.next.previous.previous.next.previous.next.next.title.should eql('Three')
   # end
   
   it "should allow both implicit :conditions and explicit in the same finder" do
     cup = Animal.first(:name => 'Cup', :conditions => ['name <> ?', 'Frog'])
     cup.should == Animal[cup.key]
   end
   
   it "should iterate in batches" do
     
     total = Animal.count
     count = 0
     
     Animal.each(:name.not => nil) do |animal|
       count += 1
     end
     
     count.should == total
     
     count = 0
     
     Animal.each(:order => "id asc", :conditions => ["id > ? AND id < ?", 0, 9985], :limit => 2) do |animal|
       count += 1
     end
     
     count.should == total
   end
   
   it "should get the right object back" do
     a = Animal.first(:name => 'Cup')
     Animal.get(a.id).should == a
     
     b = Person.first(:name => 'Amy')
     Person.get(b.id).should == b
     
     c = Person.first(:name => 'Bob')
     Person.get(c.id).should == c
     
     repository.execute("UPDATE people SET type = ? WHERE name = ?", nil, "Bob")
     
     d = Person.first(:name => 'Bob')
     Person.get(d.id).should == d
   end
   
end

=begin
context 'Sub-selection' do
  
  specify 'should return a Cup' do
    Animal[:id.select => { :name => 'cup' }].name.should == 'Cup'
  end
  
  specify 'should return all exhibits for Galveston zoo' do
    Exhibit.all(:zoo_id.select(Zoo) => { :name => 'Galveston' }).size.should == 3
  end
  
  specify 'should allow a sub-select in the select-list' do
    Animal[:select => [ :id.count ]]
  end
end
=end
