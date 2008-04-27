require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

gem 'do_sqlite3', '=0.9.0'
require 'do_sqlite3'

describe DataMapper::Adapters::DataObjectsAdapter do

  describe "when using transactions" do

    before :each do
      @adapter = DataMapper::Adapters::Sqlite3Adapter.new(:sqlite3, URI.parse("sqlite3://#{INTEGRATION_DB_PATH}"))
      @transaction = DataMapper::Adapters::Transaction.new(@adapter)
      @transaction.begin
    end

    describe "#close_connection" do
      it "should not close connections that are used for the current transaction" do
        @transaction.connection_for(@adapter).should_not_receive(:close)
        @transaction.within do
          @adapter.close_connection(@transaction.connection_for(@adapter))
        end
      end
      it "should still close connections that are not used for the current transaction" do 
        conn2 = mock("connection2")
        conn2.should_receive(:close)
        @transaction.within do
          @adapter.close_connection(conn2)
        end
      end
    end
    it "should return a fresh connection on #create_connection_outside_transaction" do
      DataObjects::Connection.should_receive(:new).once.with(@adapter.uri)
      conn = @adapter.create_connection_outside_transaction
    end
    describe "#create_connection" do
      it "should return the connection for the transaction if within a transaction" do
        @transaction.within do
          @adapter.create_connection.should == @transaction.connection_for(@adapter)
        end
      end
      it "should return new connections if not within a transaction" do
        @adapter.create_connection.should_not == @transaction.connection_for(@adapter)
      end
    end
  end

end
