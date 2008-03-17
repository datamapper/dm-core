
require Pathname(__FILE__).dirname.parent.parent + 'lib/data_mapper/adapters/abstract_adapter'
require Pathname(__FILE__).dirname.parent + 'adapter_sharedspec'

describe DataMapper::Adapters::AbstractAdapter do
  before do
    @adapter = DataMapper::Adapters::AbstractAdapter.new('mock_uri_string')
  end

  it_should_behave_like 'a DataMapper Adapter'

  %w{create read update delete}.each do |meth|
    it "should raise NotImplementedError when ##{meth} is called" do
      lambda { @adapter.send(meth.intern, nil, nil) }.should raise_error(NotImplementedError)
    end
  end

  it 'should call #create when #save is called on a new record' do
    instance = mock("Model", :"new_record?" => true)
    @adapter.should_receive(:create).with(:repository, instance)

    @adapter.save(:repository, instance)
  end

  it 'should call #update when #save is called on an existing record' do
    instance = mock("Model", :"new_record?" => false)
    @adapter.should_receive(:update).with(:repository, instance)

    @adapter.save(:repository, instance)
  end

  describe '#first' do
    it 'should raise an argument error if a limit was set in the query' do
      lambda { @adapter.first(:repository, Class, :limit => 10) }.should raise_error(ArgumentError)
    end

    it 'should pass all query options + :limit to #all' do
      @adapter.should_receive(:all) { |repo, klass, query|
        repo.should  == :repository
        klass.should == Class
        query.should be_kind_of(Hash)
        query.should have_key(:limit)
        query[:limit].should == 1
        query.should have_key(:custom)
        query[:custom].should == :opts

        [:first_record]
      }

      @adapter.first(:repository, Class, {:custom => :opts}).should == :first_record
    end
  end

  it "should raise NotImplementedError when #all is called" do
    lambda { @adapter.all(:repository, Class, {}) }.should raise_error(NotImplementedError)
  end
end
