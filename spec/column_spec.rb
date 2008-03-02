require File.dirname(__FILE__) + "/spec_helper"

describe DataMapper::Adapters::Sql::Mappings::Column do
  
  before(:all) do
    @mappings = DataMapper::Adapters::Sql::Mappings
    fixtures(:zoos)
  end
  
  def table
  	@table ||= @mappings::Table.new(repository(:mock).adapter, "Cow")
  end

  it "should only lazy loading text columns by default" do
    table = repository.table(Zoo)
    table.columns.each do  |column|
      if column.type == :text
        column.should be_lazy
      else
        column.should_not be_lazy
      end
    end
  end
  
  it "should be unique within a set" do
    columns = SortedSet.new
    
    columns << @mappings::Column.new(repository(:mock).adapter, table, :one, :string, 1)
    columns << @mappings::Column.new(repository(:mock).adapter, table, :two, :string, 2)
    columns << @mappings::Column.new(repository(:mock).adapter, table, :three, :string, 3)
    columns.should have(3).entries
    
    columns << @mappings::Column.new(repository(:mock).adapter, table, :two, :integer, 3)
    columns.should have(3).entries
    
    columns << @mappings::Column.new(repository(:mock).adapter, table, :id, :integer, -1)
    columns.should have(4).entries
  end
  
  it "should get its meta data from the database"
  
  it "should be able to rename" do
    table = repository.table(Zoo)
    name_column = table[:name]
    
    lambda { repository.query("SELECT name FROM zoos") }.should_not raise_error
    lambda { repository.query("SELECT moo FROM zoos") }.should raise_error
    
    name_column = name_column.rename!(:moo)
    name_column.name.should eql(:moo)
    
    lambda { repository.query("SELECT name FROM zoos") }.should raise_error
    lambda { repository.query("SELECT moo FROM zoos") }.should_not raise_error
    
    name_column = name_column.rename!(:name)
    name_column.name.should eql(:name)
    
    lambda { repository.query("SELECT name FROM zoos") }.should_not raise_error
    lambda { repository.query("SELECT moo FROM zoos") }.should raise_error
  end
  
  it "should create, alter and drop a column" do
    lambda { repository.query("SELECT moo FROM zoos") }.should raise_error
    
    repository.logger.debug { 'MOO' * 10 }
    
    table = repository.table(Zoo)
    Zoo.property(:moo, :string)
    moo = table[:moo]
    moo.create!
    
    lambda { repository.query("SELECT moo FROM zoos") }.should_not raise_error
    
    zoo = Zoo.create(:name => 'columns', :moo => 'AAA')
    zoo.moo.should eql('AAA')
    
    zoo.moo = 4
    zoo.save
    zoo.reload!
    zoo.moo.should eql('4')
    
    moo.type = :integer
    moo.alter!
    zoo.reload!
    zoo.moo.should eql(4)
    
    moo.drop!
    
    Zoo.send(:undef_method, :moo)
    Zoo.send(:undef_method, :moo=)
    Zoo.properties.delete_if { |x| x.name == :moo }
    
    lambda { repository.query("SELECT moo FROM zoos") }.should raise_error
  end
  
  it "should default the size of an integer column to 11" do
    integer  = @mappings::Column.new(repository(:mock).adapter, table, :age, :integer, 1)
    integer.size.should == 11    
  end
  
  it "should be able to create a column with unique index" do
    column = table.add_column("name", :string, :index => :unique)
    column.unique?.should be_true
    column.index?.should be_nil
    table.to_create_index_sql.should == []
    table.to_create_sql.should match(/UNIQUE/)
  end
  
  it "should be able to create an indexed column" do
    column = table.add_column("age", :integer, :index => true)
    column.index?.should be_true
    table.to_create_index_sql[0].should match(/CREATE INDEX cow_age_index/)
  end
end
