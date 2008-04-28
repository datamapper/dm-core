require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))
require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'lib', 'data_mapper', 'adapters', 'sqlite3_adapter'))

gem 'do_sqlite3', '=0.9.0'
require 'do_sqlite3'

describe DataMapper::Adapters::DataObjectsAdapter do

  describe "when using transactions" do

    before :each do
      @adapter = DataMapper::Adapters::Sqlite3Adapter.new(:sqlite3, URI.parse("sqlite3://#{INTEGRATION_DB_PATH}"))
      @transaction = DataMapper::Transaction.new(@adapter)
      @transaction.begin
    end

    describe "#close_connection" do
      it "should not close connections that are used for the current transaction" do
        @transaction.primitive_for(@adapter).connection.should_not_receive(:close)
        @transaction.within do
          @adapter.close_connection(@transaction.primitive_for(@adapter).connection)
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
      trans = @adapter.transaction_primitive
    end
    describe "#create_connection" do
      it "should return the connection for the transaction if within a transaction" do
        @transaction.within do
          @adapter.create_connection.should == @transaction.primitive_for(@adapter).connection
        end
      end
      it "should return new connections if not within a transaction" do
        @adapter.create_connection.should_not == @transaction.primitive_for(@adapter).connection
      end
    end
  end

end
