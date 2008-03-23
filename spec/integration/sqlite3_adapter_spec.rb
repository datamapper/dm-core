require 'pathname'
require Pathname(__FILE__).dirname.expand_path.parent + 'spec_helper'

require __DIR__.parent.parent + 'lib/data_mapper'

DataMapper.setup(:sqlite3, "sqlite3://#{Dir.getwd}/integration_test.db")

describe DataMapper::Adapters::DataObjectsAdapter do
  
  describe "reading & writing a database" do

    before do
      @adapter = repository(:sqlite3).adapter
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
      @adapter.execute('DROP TABLE "users"')
    end
  end
  
  describe "CRUD for serial Key" do
    before do      
      class VideoGame
        include DataMapper::Resource
        
        property :id, Fixnum, :serial => true
        property :name, String
      end
      
      @adapter = repository(:sqlite3).adapter
      @adapter.execute('CREATE TABLE "video_games" ("id" INTEGER PRIMARY KEY, "name" VARCHAR(50))')
    end

    it 'should be able to create a record' do
      game = VideoGame.new(:name => 'System Shock')
      repository(:sqlite3).save(game)
      
      game.should_not be_a_new_record
      game.should_not be_dirty
      
      @adapter.query('SELECT "id" FROM "video_games" WHERE "name" = ?', game.name).first.should == game.id
    end

    it 'should be able to read a record' do
      pending
    end

    it 'should be able to update a record' do
      pending
    end
    
    it 'should be able to delete a record' do
      pending
    end
    
    after do
      @adapter.execute('DROP TABLE "video_games"')
    end
  end
  
  describe "CRUD for Composite Key" do
    before do      
      class BankCustomer
        include DataMapper::Resource
        
        property :bank, String, :key => true
        property :account_number, String, :key => true
        property :name, String
      end
      
      @adapter = repository(:sqlite3).adapter
      @adapter.execute('CREATE TABLE "bank_customers" ("bank" VARCHAR(50), "account_number" VARCHAR(50), "name" VARCHAR(50))')
    end

    it 'should be able to create a record' do
      customer = BankCustomer.new(:bank => 'Community Bank', :acount_number => '123456', :name => 'David Hasselhoff')
      repository(:sqlite3).save(customer)
      
      customer.should_not be_a_new_record
      customer.should_not be_dirty
      
      row = @adapter.query('SELECT "bank", "account_number" FROM "bank_customers" WHERE "name" = ?', customer.name).first
      row.bank.should == customer.bank
      row.account_number.should == customer.account_number
    end

    it 'should be able to read a record' do
      pending
    end

    it 'should be able to update a record' do
      pending
    end
    
    it 'should be able to delete a record' do
      pending
    end
    
    after do
      @adapter.execute('DROP TABLE "bank_customers"')
    end
  end
  
end