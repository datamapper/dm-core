require File.join(File.dirname(__FILE__), '..', '..', 'spec_helper')
require File.join(File.dirname(__FILE__), '..', 'adapters', 'adapter_shared_spec')

describe DataMapper::Adapters::AbstractAdapter do

  describe DataMapper::Adapters::Transaction do
    before :each do
      @connection = mock("connection")
      @adapter = mock("adapter")
      @adapter.stub!(:create_connection).and_return(@connection)
      @transaction = DataMapper::Adapters::Transaction.new(@adapter)
    end
    it "should initialize with state :none" do
      @transaction.state.should == :none
    end
    it "should begin a transaction on #begin" do
      @adapter.should_receive(:begin_transaction).once.with(@transaction)
      @transaction.begin
      @transaction.state.should == :begin
      @transaction.connection.should == @connection
    end
    it "should rollback a transaction on #rollback" do
      @adapter.should_receive(:begin_transaction).once.with(@transaction)
      @transaction.begin
      @transaction.state.should == :begin
      @transaction.connection.should == @connection
      @adapter.should_receive(:rollback_transaction).once.with(@transaction)
      @connection.should_receive(:close).once
      @transaction.rollback
      @transaction.state.should == :rollback
    end
    it "should commit a transaction on #rollback" do
      @adapter.should_receive(:begin_transaction).once.with(@transaction)
      @transaction.begin
      @transaction.state.should == :begin
      @transaction.connection.should == @connection
      @adapter.should_receive(:commit_transaction).once.with(@transaction)
      @connection.should_receive(:close).once
      @transaction.commit
      @transaction.state.should == :commit
    end
  end

  before do
    @adapter = DataMapper::Adapters::AbstractAdapter.new(:default, 'mock_uri_string')
  end

  it_should_behave_like 'a DataMapper Adapter'

  describe "when handling transactions" do
    before :each do
      @transaction = DataMapper::Adapters::Transaction.new(@adapter)
    end
    it "should perform things within #with_transaction inside a transaction" do
      @adapter.current_transaction.should == nil
      @adapter.within_transaction?.should == false
      @adapter.with_transaction(@transaction) do 
        @adapter.current_transaction.should == @transaction
        @adapter.within_transaction?.should == true
      end
    end
    describe "using in_transaction" do
      before :each do
        @transaction = mock("transaction")
        @transaction.should_receive(:begin).once
        DataMapper::Adapters::Transaction.should_receive(:new).once.with(@adapter).and_return(@transaction)
      end
      it "should commit after executing given block in #in_transaction" do
        @transaction.should_receive(:state).once.and_return(:begin)
        @transaction.should_receive(:commit).once
        @adapter.current_transaction.should == nil
        @adapter.within_transaction?.should == false
        @adapter.in_transaction do |trans|
          @adapter.current_transaction.should == @transaction
          trans.should == @transaction
          @adapter.within_transaction?.should == true
        end
      end
      it "should rollback and raise exception after executing given block in #in_transaction if the block raises exception" do
        @transaction.should_receive(:state).once.and_return(:begin)
        @transaction.should_receive(:rollback).once
        @adapter.current_transaction.should == nil
        @adapter.within_transaction?.should == false
        lambda do
          @adapter.in_transaction do |trans|
            raise "hehu"
          end
        end.should raise_error("hehu")
      end
    end
  end

  it "should raise NotImplementedError when #begin_transaction is called" do
    lambda do @adapter.begin_transaction(nil) end.should raise_error(NotImplementedError)
  end

  it "should raise NotImplementedError when #commit_transaction is called" do
    lambda do @adapter.commit_transaction(nil) end.should raise_error(NotImplementedError)
  end

  it "should raise NotImplementedError when #rollback_transaction is called" do
    lambda do @adapter.rollback_transaction(nil) end.should raise_error(NotImplementedError)
  end

  it "should raise NotImplementedError when #create is called" do
    lambda { @adapter.create(:repository, :instance) }.should raise_error(NotImplementedError)
  end

  it "should raise NotImplementedError when #read is called" do
    lambda { @adapter.read(:repository, :resource, [:key]) }.should raise_error(NotImplementedError)
  end

  it "should raise NotImplementedError when #update is called" do
    lambda { @adapter.update(:repository, :instance) }.should raise_error(NotImplementedError)
  end

  it "should raise NotImplementedError when #delete is called" do
    lambda { @adapter.delete(:repository, :instance) }.should raise_error(NotImplementedError)
  end

  it "should raise NotImplementedError when #read_one is called" do
    lambda { @adapter.read_one(:repository, :query) }.should raise_error(NotImplementedError)
  end

  it "should raise NotImplementedError when #read_set is called" do
    lambda { @adapter.read_set(:repository, :query) }.should raise_error(NotImplementedError)
  end

  it "should raise NotImplementedError when #delete_set is called" do
    lambda { @adapter.delete_set(:repository, :query) }.should raise_error(NotImplementedError)
  end
  
  it "should raise NotImplementedError when #create_model_storage is called" do
    lambda { @adapter.create_model_storage(:repository, :resource) }.should raise_error(NotImplementedError)
  end
  
  it "should raise NotImplementedError when #destroy_model_storage is called" do
    lambda { @adapter.destroy_model_storage(:repository, :resource) }.should raise_error(NotImplementedError)
  end
  
  it "should raise NotImplementedError when #alter_model_storage is called" do
    lambda { @adapter.alter_model_storage(:repository, :resource) }.should raise_error(NotImplementedError)
  end
  
  it "should raise NotImplementedError when #create_property_storage is called" do
    lambda { @adapter.create_property_storage(:repository, :property) }
  end
  
  it "should raise NotImplementedError when #destroy_property_storage is called" do
    lambda { @adapter.destroy_property_storage(:repository, :property) }
  end
  
  it "should raise NotImplementedError when #alter_property_storage is called" do
    lambda { @adapter.alter_property_storage(:repository, :property) }
  end
end
