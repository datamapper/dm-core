require File.join(File.dirname(__FILE__), '../../lib/data_mapper')
require File.join(File.dirname(__FILE__), '../../lib/data_mapper/adapters/data_object_adapter')
require File.join(File.dirname(__FILE__), '..', 'adapter_sharedspec')

describe DataMapper::Adapters::DataObjectAdapter do
  before do
    @adapter = DataMapper::Adapters::DataObjectAdapter.new('mock::/localhost')

  end

  it_should_behave_like 'a DataMapper Adapter'

  describe '#execute' do
    before do
      @mock_command = mock('Command', :execute_non_query => nil)
      @mock_db = mock('DB Connection', :create_command => @mock_command, :close => true)

      @adapter.stub!(:create_connection).and_return(@mock_db)
    end 

    it 'should #create_command from the sql passed' do
      @mock_db.should_receive(:create_command).with('SQL STRING').and_return(@mock_command)
      @adapter.execute('SQL STRING')
    end

    it 'should pass any additional args to #execute_non_query' do
      @mock_command.should_receive(:execute_non_query).with(:args)
      @adapter.execute('SQL STRING', :args)
    end

    it 'should return the result of #execute_non_query' do
      @mock_command.should_receive(:execute_non_query).and_return(:result_set)

      @adapter.execute('SQL STRING').should == :result_set
    end

    it 'should log any errors, then re-raise them' do
      pending
      @mock_command.should_receive(:execute_non_query).and_raise("Oh Noes!")
      #DataMapper.logger.should_receive(:error)

      lambda { @adapter.execute('SQL STRING') }.should raise_error("Oh Noes!")
    end


    it 'should always close the db connection' do
      @mock_command.should_receive(:execute_non_query).and_raise("Oh Noes!")
      @mock_db.should_receive(:close)

      lambda { @adapter.execute('SQL STRING') }.should raise_error("Oh Noes!")
    end
  end

  describe '#query' do

  end
end
