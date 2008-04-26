require File.join(File.dirname(__FILE__), '..', '..', 'spec_helper')
require File.join(File.dirname(__FILE__), '..', 'adapters', 'adapter_shared_spec')

describe DataMapper::Adapters::AbstractAdapter do

  describe DataMapper::Adapters::Transaction do

    before :all do
      class Smurf
        include DataMapper::Resource
        property :id, Fixnum, :key => true
      end
    end

    before :each do
      @adapter = mock("adapter")
      @repository = mock("repository")
      @repository_adapter = mock("repository adapter")
      @resource = Smurf.new
      @connection = mock("connection")
      @repository_connection = mock("repository connection")
      @array = [@adapter, @repository]

      @adapter.should_receive(:is_a?).any_number_of_times.with(Array).and_return(false)
      @adapter.should_receive(:is_a?).any_number_of_times.with(DataMapper::Adapters::AbstractAdapter).and_return(true)
      @adapter.should_receive(:create_connection_outside_transaction).any_number_of_times.and_return(@connection)
      @repository.should_receive(:is_a?).any_number_of_times.with(Array).and_return(false)
      @repository.should_receive(:is_a?).any_number_of_times.with(DataMapper::Adapters::AbstractAdapter).and_return(false)
      @repository.should_receive(:is_a?).any_number_of_times.with(DataMapper::Repository).and_return(true)
      @repository.should_receive(:adapter).any_number_of_times.and_return(@repository_adapter)
      @repository_adapter.should_receive(:is_a?).any_number_of_times.with(Array).and_return(false)
      @repository_adapter.should_receive(:is_a?).any_number_of_times.with(DataMapper::Adapters::AbstractAdapter).and_return(true)
      @repository_adapter.should_receive(:create_connection_outside_transaction).any_number_of_times.and_return(@repository_connection)
    end

    it "should be able to initialize with an Array" do
      DataMapper::Adapters::Transaction.new(@array)
    end
    it "should be able to initialize with DataMapper::Adapters::AbstractAdapters" do
      DataMapper::Adapters::Transaction.new(@adapter)
    end
    it "should be able to initialize with DataMapper::Repositories" do
      DataMapper::Adapters::Transaction.new(@repository)
    end
    it "should be able to initialize with DataMapper::Resource subclasses" do
      DataMapper::Adapters::Transaction.new(Smurf)
    end
    it "should be able to initialize with DataMapper::Resources" do
      DataMapper::Adapters::Transaction.new(Smurf.new)
    end
    it "should initialize with no connections" do
      DataMapper::Adapters::Transaction.new.connections.empty?.should == true
    end
    it "should initialize with state :none" do
      DataMapper::Adapters::Transaction.new.state.should == :none
    end
    it "should initialize with a more or less unique id" do
      DataMapper::Adapters::Transaction.new.id.should_not == DataMapper::Adapters::Transaction.new.id
    end
    it "should initialize the adapters given on creation" do
      DataMapper::Adapters::Transaction.new(Smurf).adapters.should == {Smurf.repository.adapter => :none}
    end
    it "should be able receive multiple adapters on creation" do
      DataMapper::Adapters::Transaction.new(Smurf, @resource, @adapter, @repository)
    end
    it "should be able to initialize with a block" do
      p = Proc.new do end
      @adapter.stub!(:begin_transaction)
      @adapter.stub!(:prepare_transaction)
      @adapter.stub!(:commit_transaction)
      @adapter.stub!(:push_transaction)
      @adapter.stub!(:pop_transaction)
      @connection.stub!(:close)
      DataMapper::Adapters::Transaction.new(@adapter, &p)
    end
    it "should accept new adapters after creation" do
      t = DataMapper::Adapters::Transaction.new(@adapter, @repository)
      t.adapters.should == {@adapter => :none, @repository_adapter => :none}
      t.link(@resource)
      t.adapters.should == {@adapter => :none, @repository_adapter => :none, Smurf.repository.adapter => :none}
    end
    it "should not accept new adapters after state is changed" do
      t = DataMapper::Adapters::Transaction.new(@adapter, @repository)
      @adapter.stub!(:begin_transaction)
      @repository_adapter.stub!(:begin_transaction)
      t.begin
      lambda do t.link(@resource) end.should raise_error(Exception, /Illegal state/)
    end
    describe "#begin" do
      before :each do
        @transaction = DataMapper::Adapters::Transaction.new(@adapter, @repository)
      end
      it "should raise error if state is changed" do
        @adapter.stub!(:begin_transaction)
        @repository_adapter.stub!(:begin_transaction)
        @transaction.begin
        lambda do @transaction.begin end.should raise_error(Exception, /Illegal state/)
      end
      it "should try to connect each adapter (or log fatal error), then begin each adapter (or rollback and close)" do
        @transaction.should_receive(:each_adapter).once.with(:connect_adapter, [:log_fatal_transaction_breakage])
        @transaction.should_receive(:each_adapter).once.with(:begin_adapter, [:rollback_and_close_adapter_if_begin, :close_adapter_if_none])
        @transaction.begin
      end
      it "should leave with state :begin" do
        @adapter.stub!(:begin_transaction)
        @repository_adapter.stub!(:begin_transaction)
        @transaction.begin
        @transaction.state.should == :begin
      end
    end
    describe "#rollback" do
      before :each do
        @transaction = DataMapper::Adapters::Transaction.new(@adapter, @repository)
      end
      it "should raise error if state is :none" do
        lambda do @transaction.rollback end.should raise_error(Exception, /Illegal state/)
      end
      it "should raise error if state is :commit" do
        @adapter.stub!(:begin_transaction)
        @repository_adapter.stub!(:begin_transaction)
        @adapter.stub!(:prepare_transaction)
        @repository_adapter.stub!(:prepare_transaction)
        @adapter.stub!(:commit_transaction)
        @repository_adapter.stub!(:commit_transaction)
        @connection.stub!(:close)
        @repository_connection.stub!(:close)
        @transaction.begin
        @transaction.commit
        lambda do @transaction.rollback end.should raise_error(Exception, /Illegal state/)
      end
      it "should try to rollback each adapter (or rollback and close), then then close (or log fatal error)" do
        @transaction.should_receive(:each_adapter).once.with(:connect_adapter, [:log_fatal_transaction_breakage])
        @transaction.should_receive(:each_adapter).once.with(:begin_adapter, [:rollback_and_close_adapter_if_begin, :close_adapter_if_none])
        @transaction.should_receive(:each_adapter).once.with(:rollback_adapter, [:rollback_and_close_adapter_if_begin, :close_adapter_if_none])
        @transaction.should_receive(:each_adapter).once.with(:close_adapter, [:log_fatal_transaction_breakage])
        @transaction.begin
        @transaction.rollback
      end
      it "should leave with state :rollback" do
        @adapter.stub!(:begin_transaction)
        @repository_adapter.stub!(:begin_transaction)
        @adapter.stub!(:rollback_transaction)
        @repository_adapter.stub!(:rollback_transaction)
        @connection.stub!(:close)
        @repository_connection.stub!(:close)
        @transaction.begin
        @transaction.rollback
        @transaction.state.should == :rollback
      end
    end
    describe "#commit" do
      describe "without a block" do
        before :each do
          @transaction = DataMapper::Adapters::Transaction.new(@adapter, @repository)
        end
        it "should raise error if state is :none" do
          lambda do @transaction.commit end.should raise_error(Exception, /Illegal state/)
        end
        it "should raise error if state is :commit" do
          @adapter.stub!(:begin_transaction)
          @repository_adapter.stub!(:begin_transaction)
          @adapter.stub!(:prepare_transaction)
          @repository_adapter.stub!(:prepare_transaction)
          @adapter.stub!(:commit_transaction)
          @repository_adapter.stub!(:commit_transaction)
          @connection.stub!(:close)
          @repository_connection.stub!(:close)
          @transaction.begin
          @transaction.commit
          lambda do @transaction.commit end.should raise_error(Exception, /Illegal state/)
        end
        it "should raise error if state is :rollback" do
          @adapter.stub!(:begin_transaction)
          @repository_adapter.stub!(:begin_transaction)
          @adapter.stub!(:rollback_transaction)
          @repository_adapter.stub!(:rollback_transaction)
          @connection.stub!(:close)
          @repository_connection.stub!(:close)
          @transaction.begin
          @transaction.rollback
          lambda do @transaction.commit end.should raise_error(Exception, /Illegal state/)
        end
        it "should try to prepare each adapter (or rollback and close), then commit each adapter (or log fatal error), then close (or log fatal error)" do
          @transaction.should_receive(:each_adapter).once.with(:connect_adapter, [:log_fatal_transaction_breakage])
          @transaction.should_receive(:each_adapter).once.with(:begin_adapter, [:rollback_and_close_adapter_if_begin, :close_adapter_if_none])
          @transaction.should_receive(:each_adapter).once.with(:prepare_adapter, [:rollback_and_close_adapter_if_begin, :rollback_prepared_and_close_adapter_if_prepare])
          @transaction.should_receive(:each_adapter).once.with(:commit_adapter, [:log_fatal_transaction_breakage])
          @transaction.should_receive(:each_adapter).once.with(:close_adapter, [:log_fatal_transaction_breakage])
          @transaction.begin
          @transaction.commit
        end
        it "should leave with state :commit" do
          @adapter.stub!(:begin_transaction)
          @repository_adapter.stub!(:begin_transaction)
          @adapter.stub!(:prepare_transaction)
          @repository_adapter.stub!(:prepare_transaction)
          @adapter.stub!(:commit_transaction)
          @repository_adapter.stub!(:commit_transaction)
          @connection.stub!(:close)
          @repository_connection.stub!(:close)
          @transaction.begin
          @transaction.commit
          @transaction.state.should == :commit
        end
      end
      describe "with a block" do
        before :each do
          @transaction = DataMapper::Adapters::Transaction.new(@adapter, @repository)
        end
        it "should raise if state is not :none" do
          @adapter.stub!(:begin_transaction)
          @repository_adapter.stub!(:begin_transaction)
          @transaction.begin
          lambda do @transaction.commit do end end.should raise_error(Exception, /Illegal state/)
        end
        it "should begin, yield and commit if the block raises no exception" do
          @repository_adapter.should_receive(:begin_transaction).once.with(@transaction)
          @repository_adapter.should_receive(:prepare_transaction).once.with(@transaction)
          @repository_adapter.should_receive(:commit_transaction).once.with(@transaction)
          @repository_connection.should_receive(:close).once
          @adapter.should_receive(:begin_transaction).once.with(@transaction)
          @adapter.should_receive(:prepare_transaction).once.with(@transaction)
          @adapter.should_receive(:commit_transaction).once.with(@transaction)
          @connection.should_receive(:close).once
          p = Proc.new do end
          @transaction.should_receive(:within).once.with(&p)
          @transaction.commit(&p)
        end
        it "should rollback if the block raises an exception" do
          @repository_adapter.should_receive(:begin_transaction).once.with(@transaction)
          @repository_adapter.should_receive(:rollback_transaction).once.with(@transaction)
          @repository_connection.should_receive(:close).once
          @adapter.should_receive(:begin_transaction).once.with(@transaction)
          @adapter.should_receive(:rollback_transaction).once.with(@transaction)
          @connection.should_receive(:close).once
          p = Proc.new do raise "test exception, never mind me" end
          @transaction.should_receive(:within).once.with(&p)
          lambda do @transaction.commit(&p) end.should raise_error(Exception, /test exception, never mind me/)
        end
      end
    end
    describe "#within" do
      before :each do
        @transaction = DataMapper::Adapters::Transaction.new(@adapter, @repository)
      end
      it "should raise if no block is provided" do
        lambda do @transaction.within end.should raise_error(Exception, /No block/)
      end
      it "should raise if state is not :begin" do
        lambda do @transaction.within do end end.should raise_error(Exception, /Illegal state/)
      end
      it "should push itself on the per thread transaction context of each adapter and then pop itself out again" do
        @repository_adapter.should_receive(:begin_transaction).once.with(@transaction)
        @adapter.should_receive(:begin_transaction).once.with(@transaction)
        @repository_adapter.should_receive(:push_transaction).once.with(@transaction)
        @adapter.should_receive(:push_transaction).once.with(@transaction)
        @repository_adapter.should_receive(:pop_transaction).once
        @adapter.should_receive(:pop_transaction).once
        @transaction.begin
        @transaction.within do end
      end
      it "should push itself on the per thread transaction context of each adapter and then pop itself out again even if an exception was raised" do
        @repository_adapter.should_receive(:begin_transaction).once.with(@transaction)
        @adapter.should_receive(:begin_transaction).once.with(@transaction)
        @repository_adapter.should_receive(:push_transaction).once.with(@transaction)
        @adapter.should_receive(:push_transaction).once.with(@transaction)
        @repository_adapter.should_receive(:pop_transaction).once
        @adapter.should_receive(:pop_transaction).once
        @transaction.begin
        lambda do @transaction.within do raise "test exception, never mind me" end end.should raise_error(Exception, /test exception, never mind me/)
      end
    end
    describe "#method_missing" do
      before :each do
        @transaction = DataMapper::Adapters::Transaction.new(@adapter, @repository)
        @adapter.should_receive(:is_a?).any_number_of_times.with(Spec::Mocks::AnyArgsConstraint).and_return(false)
        @adapter.should_receive(:is_a?).any_number_of_times.with(Spec::Mocks::NoArgsConstraint).and_return(false)
        @adapter.should_receive(:is_a?).any_number_of_times.with(Regexp).and_return(false)
      end
      it "should delegate calls to [a method we have]_if_[state](adapter) to [a method we have](adapter) if state of adapter is [state]" do
        @transaction.should_receive(:state_for).once.with(@adapter).and_return(:begin)
        @transaction.should_receive(:connect_adapter).once.with(@adapter)
        @transaction.connect_adapter_if_begin(@adapter)
      end
      it "should not delegate calls to [a method we have]_if_[state](adapter) to [a method we have](adapter) if state of adapter is not [state]" do
        @transaction.should_receive(:state_for).once.with(@adapter).and_return(:commit)
        @transaction.should_not_receive(:connect_adapter).with(@adapter)
        @transaction.connect_adapter_if_begin(@adapter)
      end
      it "should delegate calls to [a method we have]_unless_[state](adapter) to [a method we have](adapter) if state of adapter is not [state]" do
        @transaction.should_receive(:state_for).once.with(@adapter).and_return(:none)
        @transaction.should_receive(:connect_adapter).once.with(@adapter)
        @transaction.connect_adapter_unless_begin(@adapter)
      end
      it "should not delegate calls to [a method we have]_unless_[state](adapter) to [a method we have](adapter) if state of adapter is [state]" do
        @transaction.should_receive(:state_for).once.with(@adapter).and_return(:begin)
        @transaction.should_not_receive(:connect_adapter).with(@adapter)
        @transaction.connect_adapter_unless_begin(@adapter)
      end
      it "should not delegate calls whose first argument is not a DataMapper::Adapters::AbstractAdapter" do
        lambda do @transaction.connect_adapter_unless_begin("plur") end.should raise_error
      end
      it "should not delegate calls that do not look like an if or unless followed by a state" do
        lambda do @transaction.connect_adapter_unless_hepp(@adapter) end.should raise_error
        lambda do @transaction.connect_adapter_when_begin(@adapter) end.should raise_error
      end
      it "should not delegate calls that we can not respond to" do
        lambda do @transaction.connect_adapters_unless_begin(@adapter) end.should raise_error
        lambda do @transaction.connect_adapters_if_begin(@adapter) end.should raise_error
      end
    end
    it "should be able to produce the connection for an adapter" do
      @adapter.stub!(:begin_transaction)
      @repository_adapter.stub!(:begin_transaction)
      @transaction = DataMapper::Adapters::Transaction.new(@adapter, @repository)
      @transaction.begin
      @transaction.connection_for(@adapter).should == @connection
    end
    describe "#each_adapter" do
      before :each do
        @transaction = DataMapper::Adapters::Transaction.new(@adapter, @repository)
        @adapter.should_receive(:is_a?).any_number_of_times.with(Spec::Mocks::AnyArgsConstraint).and_return(false)
        @adapter.should_receive(:is_a?).any_number_of_times.with(Spec::Mocks::NoArgsConstraint).and_return(false)
        @adapter.should_receive(:is_a?).any_number_of_times.with(Regexp).and_return(false)
        @repository_adapter.should_receive(:is_a?).any_number_of_times.with(Spec::Mocks::AnyArgsConstraint).and_return(false)
        @repository_adapter.should_receive(:is_a?).any_number_of_times.with(Spec::Mocks::NoArgsConstraint).and_return(false)
        @repository_adapter.should_receive(:is_a?).any_number_of_times.with(Regexp).and_return(false)
      end
      it "should send the first argument to itself once for each adapter" do
        @transaction.should_receive(:plupp).once.with(@adapter)
        @transaction.should_receive(:plupp).once.with(@repository_adapter)
        @transaction.instance_eval do each_adapter(:plupp, [:plur]) end
      end
      it "should stop sending if any call raises an exception, then send each element of the second argument to itself with each adapter as argument" do
        a1 = @repository_adapter
        a2 = @adapter
        @transaction.adapters.instance_eval do
          @a1 = a1
          @a2 = a2
          def each(&block)
            yield(@a1, :none)
            yield(@a2, :none)
          end
        end
        @transaction.should_receive(:plupp).once.with(@repository_adapter).and_throw(Exception.new("test error - dont mind me"))
        @transaction.should_not_receive(:plupp).with(@adapter)
        @transaction.should_receive(:plur).once.with(@adapter)
        @transaction.should_receive(:plur).once.with(@repository_adapter)
        lambda do @transaction.instance_eval do each_adapter(:plupp, [:plur]) end end.should raise_error(Exception, /test error - dont mind me/)
      end
      it "should send each element of the second argument to itself with each adapter as argument even if exceptions occur in the process" do
        a1 = @repository_adapter
        a2 = @adapter
        @transaction.adapters.instance_eval do
          @a1 = a1
          @a2 = a2
          def each(&block)
            yield(@a1, :none)
            yield(@a2, :none)
          end
        end
        @transaction.should_receive(:plupp).once.with(@repository_adapter).and_throw(Exception.new("test error - dont mind me"))
        @transaction.should_not_receive(:plupp).with(@adapter)
        @transaction.should_receive(:plur).once.with(@adapter).and_throw(Exception.new("another test error"))
        @transaction.should_receive(:plur).once.with(@repository_adapter).and_throw(Exception.new("yet another error"))
        lambda do @transaction.instance_eval do each_adapter(:plupp, [:plur]) end end.should raise_error(Exception, /test error - dont mind me/)
      end
    end
    it "should be able to return the state for a given adapter" do
      @transaction = DataMapper::Adapters::Transaction.new(@adapter, @repository)
      a1 = @adapter
      a2 = @repository_adapter
      @transaction.instance_eval do state_for(a1) end.should == :none
      @transaction.instance_eval do state_for(a2) end.should == :none
      @transaction.instance_eval do @adapters[a1] = :begin end
      @transaction.instance_eval do state_for(a1) end.should == :begin
      @transaction.instance_eval do state_for(a2) end.should == :none
    end
    describe "#do_adapter" do
      before :each do
        @transaction = DataMapper::Adapters::Transaction.new(@adapter, @repository)
        @adapter.should_receive(:is_a?).any_number_of_times.with(Spec::Mocks::AnyArgsConstraint).and_return(false)
        @adapter.should_receive(:is_a?).any_number_of_times.with(Spec::Mocks::NoArgsConstraint).and_return(false)
        @adapter.should_receive(:is_a?).any_number_of_times.with(Regexp).and_return(false)
      end
      it "should raise if there is no connection for the adapter" do
        a1 = @adapter
        lambda do @transaction.instance_eval do do_adapter(a1, :ping, :pong) end end.should raise_error(Exception, /No connection/)
      end
      it "should raise if the adapter has the wrong state" do
        @adapter.stub!(:begin_transaction)
        @repository_adapter.stub!(:begin_transaction)
        @transaction.begin
        a1 = @adapter
        @adapter.should_not_receive(:ping_transaction).with(@transaction)
        lambda do @transaction.instance_eval do do_adapter(a1, :ping, :pong) end end.should raise_error(Exception, /Illegal state/)
      end
      it "should delegate to the adapter if the connection exists and we have the right state" do
        @adapter.stub!(:begin_transaction)
        @repository_adapter.stub!(:begin_transaction)
        @transaction.begin
        a1 = @adapter
        @adapter.should_receive(:ping_transaction).once.with(@transaction)
        @transaction.instance_eval do do_adapter(a1, :ping, :begin) end
      end
    end
    describe "#connect_adapter" do
      before :each do
        @other_adapter = mock("adapter")
        @other_adapter.should_receive(:is_a?).any_number_of_times.with(Array).and_return(false)
        @other_adapter.should_receive(:is_a?).any_number_of_times.with(DataMapper::Adapters::AbstractAdapter).and_return(true)
        @transaction = DataMapper::Adapters::Transaction.new(@other_adapter)
      end
      it "should be able to connect an adapter" do
        a1 = @other_adapter
        @other_adapter.should_receive(:create_connection_outside_transaction).once.and_return(@connection)
        @transaction.instance_eval do connect_adapter(a1) end
        @transaction.connections[@other_adapter].should == @connection
      end
    end
    describe "#close adapter" do
      before :each do
        @other_adapter = mock("adapter")
        @other_adapter.should_receive(:is_a?).any_number_of_times.with(Array).and_return(false)
        @other_adapter.should_receive(:is_a?).any_number_of_times.with(DataMapper::Adapters::AbstractAdapter).and_return(true)
        @transaction = DataMapper::Adapters::Transaction.new(@other_adapter)
      end
      it "should be able to close the connection of an adapter" do
        a1 = @other_adapter
        @connection.should_receive(:close).once
        @other_adapter.should_receive(:create_connection_outside_transaction).once.and_return(@connection)
        @transaction.instance_eval do connect_adapter(a1) end
        @transaction.connections[@other_adapter].should == @connection
        @transaction.instance_eval do close_adapter(a1) end
        @transaction.connections[@other_adapter].should == nil
      end
    end
    describe "the transaction operation methods" do
      before :each do
        @other_adapter = mock("adapter")
        @other_adapter.should_receive(:is_a?).any_number_of_times.with(Array).and_return(false)
        @other_adapter.should_receive(:is_a?).any_number_of_times.with(DataMapper::Adapters::AbstractAdapter).and_return(true)
        @other_adapter.should_receive(:is_a?).any_number_of_times.with(Spec::Mocks::AnyArgsConstraint).and_return(false)
        @other_adapter.should_receive(:is_a?).any_number_of_times.with(Spec::Mocks::NoArgsConstraint).and_return(false)
        @other_adapter.should_receive(:is_a?).any_number_of_times.with(Regexp).and_return(false)
        @transaction = DataMapper::Adapters::Transaction.new(@other_adapter)
      end
      it "should only allow adapters in state :none to begin" do
        a1 = @other_adapter
        @transaction.should_receive(:do_adapter).once.with(@other_adapter, :begin, :none)
        @transaction.instance_eval do begin_adapter(a1) end
      end
      it "should only allow adapters in state :begin to prepare" do
        a1 = @other_adapter
        @transaction.should_receive(:do_adapter).once.with(@other_adapter, :prepare, :begin)
        @transaction.instance_eval do prepare_adapter(a1) end
      end
      it "should only allow adapters in state :prepare to commit" do
        a1 = @other_adapter
        @transaction.should_receive(:do_adapter).once.with(@other_adapter, :commit, :prepare)
        @transaction.instance_eval do commit_adapter(a1) end
      end
      it "should only allow adapters in state :begin to rollback" do
        a1 = @other_adapter
        @transaction.should_receive(:do_adapter).once.with(@other_adapter, :rollback, :begin)
        @transaction.instance_eval do rollback_adapter(a1) end
      end
      it "should only allow adapters in state :prepare to rollback_prepared" do
        a1 = @other_adapter
        @transaction.should_receive(:do_adapter).once.with(@other_adapter, :rollback_prepared, :prepare)
        @transaction.instance_eval do rollback_prepared_adapter(a1) end
      end
      it "should do delegate properly for rollback_and_close" do
        a1 = @other_adapter
        @transaction.should_receive(:rollback_adapter).once.with(@other_adapter)
        @transaction.should_receive(:close_adapter).once.with(@other_adapter)
        @transaction.instance_eval do rollback_and_close_adapter(a1) end
      end
      it "should do delegate properly for rollback_prepared_and_close" do
        a1 = @other_adapter
        @transaction.should_receive(:rollback_prepared_adapter).once.with(@other_adapter)
        @transaction.should_receive(:close_adapter).once.with(@other_adapter)
        @transaction.instance_eval do rollback_prepared_and_close_adapter(a1) end
      end
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
    it "should be able to push and pop transactions on the current stack" do
      @adapter.current_transaction.should == nil
      @adapter.within_transaction?.should == false
      @adapter.push_transaction(@transaction)
      @adapter.current_transaction.should == @transaction
      @adapter.within_transaction?.should == true
      @adapter.push_transaction(@transaction)
      @adapter.current_transaction.should == @transaction
      @adapter.within_transaction?.should == true
      @adapter.pop_transaction
      @adapter.current_transaction.should == @transaction
      @adapter.within_transaction?.should == true
      @adapter.pop_transaction
      @adapter.current_transaction.should == nil
      @adapter.within_transaction?.should == false
    end
  end

  it "should raise NotImplementedError when #begin_transaction is called" do
    lambda do @adapter.begin_transaction(nil) end.should raise_error(NotImplementedError)
  end

  it "should raise NotImplementedError when #prepare_transaction is called" do
    lambda do @adapter.prepare_transaction(nil) end.should raise_error(NotImplementedError)
  end

  it "should raise NotImplementedError when #commit_transaction is called" do
    lambda do @adapter.commit_transaction(nil) end.should raise_error(NotImplementedError)
  end

  it "should raise NotImplementedError when #rollback_transaction is called" do
    lambda do @adapter.rollback_transaction(nil) end.should raise_error(NotImplementedError)
  end

  it "should raise NotImplementedError when #rollback_prepared_transaction is called" do
    lambda do @adapter.rollback_prepared_transaction(nil) end.should raise_error(NotImplementedError)
  end

  it "should raise NotImplementedError when #create_connection is called" do
    lambda do @adapter.create_connection end.should raise_error(NotImplementedError)
  end

  it "should raise NotImplementedError when #create_connection_outside_transaction is called" do
    lambda do @adapter.create_connection_outside_transaction end.should raise_error(NotImplementedError)
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
