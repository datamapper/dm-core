require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

begin
  gem 'do_postgres', '=0.9.0'
  require 'do_postgres'
  
  gem 'do_mysql', '=0.9.0'
  require 'do_mysql'
  
  DataMapper.setup(:postgres, ENV["POSTGRES_SPEC_URI"] || "postgres://127.0.0.1/dm_core_test")
  DataMapper.setup(:mysql, ENV["MYSQL_SPEC_URI"] || "mysql://127.0.0.1/dm_core_test")
  
  class Sputnik
    include DataMapper::Resource

    property :id, Fixnum, :serial => true
    property :name, DM::Text
  end

  describe DataMapper::Transaction do
    before :each do
      @adapter1 = repository(:postgres).adapter
      
      Sputnik.auto_migrate!(:postgres)
      
      @adapter2 = repository(:mysql).adapter
      
      Sputnik.auto_migrate!(:mysql)
    end
    
    it "should commit changes to all involved adapters on a two phase commit" do
      DataMapper::Transaction.new(@adapter1, @adapter2) do
        @adapter1.execute("INSERT INTO sputniks (name) VALUES ('hepp')")
        @adapter2.execute("INSERT INTO sputniks (name) VALUES ('hepp')")
      end
      @adapter1.query("SELECT * FROM sputniks").size.should == 1
      @adapter2.query("SELECT * FROM sputniks").size.should == 1
    end

    it "should not commit any changes if the block raises an exception" do
      lambda do 
        DataMapper::Transaction.new(@adapter1, @adapter2) do
          @adapter1.execute("INSERT INTO sputniks (name) VALUES ('hepp')")
          @adapter2.execute("INSERT INTO sputniks (name) VALUES ('hepp')")
          raise "plur"
        end
      end.should raise_error(Exception, /plur/)
      @adapter1.query("SELECT * FROM sputniks").should == []
      @adapter2.query("SELECT * FROM sputniks").should == []
    end

    it "should not commit any changes if any of the adapters doesnt prepare properly" do
      lambda do
        DataMapper::Transaction.new(@adapter1, @adapter2) do |transaction|
          @adapter1.execute("INSERT INTO sputniks (name) VALUES ('hepp')")
          @adapter2.execute("INSERT INTO sputniks (name) VALUES ('hepp')")
          transaction.primitive_for(@adapter1).should_receive(:prepare).once.and_throw(Exception.new("I am the famous test exception"))
        end
      end.should raise_error(Exception, /I am the famous test exception/)
      @adapter1.query("SELECT * FROM sputniks").should == []
      @adapter2.query("SELECT * FROM sputniks").should == []
    end
  end

rescue LoadError => e
  describe 'do_postgres and do_mysql for transaction specs' do
    it 'should be required' do
      fail "PostgreSQL integration specs not run! Could not load the gems: #{e}"
    end
  end
end
