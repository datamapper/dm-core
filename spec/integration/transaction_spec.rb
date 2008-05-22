require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

if HAS_MYSQL && HAS_POSTGRES
  class Sputnik
    include DataMapper::Resource

    property :id, Integer, :serial => true
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
          transaction.primitive_for(@adapter1).should_receive(:prepare).and_throw(Exception.new("I am the famous test exception"))
        end
      end.should raise_error(Exception, /I am the famous test exception/)
      @adapter1.query("SELECT * FROM sputniks").should == []
      @adapter2.query("SELECT * FROM sputniks").should == []
    end
  end
end
