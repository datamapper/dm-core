require 'pathname'
require Pathname(__FILE__).dirname.expand_path.parent + 'spec_helper'

require __DIR__.parent.parent + 'lib/data_mapper'
require __DIR__.parent.parent + 'lib/data_mapper/adapters/data_objects_adapter'

DataMapper.setup(:default, "sqlite3://#{Dir.getwd}/integration_test.db")

describe DataMapper::Adapters::DataObjectsAdapter, "reading & writing a database" do

  before do
    @adapter = DataMapper.repository(:default).adapter
    @adapter.execute("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)")
    @adapter.execute("INSERT INTO users (name) VALUES ('Paul')")
  end

  it 'should be able to #execute an arbitrary query' do
    result = @adapter.execute("INSERT INTO users (name) VALUES ('Sam')")

    result.affected_rows.should == 1    
  end

  it 'should be able to #query' do
    result = @adapter.query("SELECT * FROM users")

    result.should be_kind_of(Array)
    row = result.first
    row.should be_kind_of(Struct)
    row.members.should == %w{id name}

    row.id.should == 1
    row.name.should == 'Paul'
  end

  it 'should return an empty array if #query found no rows' do
    @adapter.execute("DELETE FROM users")

    result = nil
    lambda { result = @adapter.query("SELECT * FROM users") }.should_not raise_error

    result.should be_kind_of(Array)
    result.size.should == 0
  end

  after do
    @adapter.execute("DROP TABLE users")
  end

end
