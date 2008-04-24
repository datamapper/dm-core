require 'pathname'
require Pathname(__FILE__).dirname.expand_path.parent + 'spec_helper'
require DataMapper.root / 'lib' / 'data_mapper' / 'adapters' / 'sqlite3_adapter'
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
        @transaction.connection.should_not_receive(:close)
        @adapter.with_transaction(@transaction) do
          @adapter.close_connection(@transaction.connection)
        end
      end
      it "should still close connections that are not used for the current transaction" do 
        conn2 = mock("connection2")
        conn2.should_receive(:close)
        @adapter.with_transaction(@transaction) do
          @adapter.close_connection(conn2)
        end
      end
    end
    describe "#create_connection" do
      it "should return the connection for the transaction if within a transaction" do
        @adapter.with_transaction(@transaction) do
          @adapter.create_connection.should == @transaction.connection
        end
      end
      it "should return new connections if not within a transaction" do
        @adapter.create_connection.should_not == @transaction.connection
      end
    end
  end

end
