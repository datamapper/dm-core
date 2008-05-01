require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

describe DataMapper::Repository do

  before do
    @adapter = DataMapper::Repository.adapters[:repository_spec] || DataMapper.setup(:repository_spec, 'mock://localhost')

    class Vegetable
      include DataMapper::Resource

      property :id, Fixnum, :serial => true
      property :name, String

    end
  end

  describe "managing transactions" do
    it "should create a new Transaction with itself as argument when #transaction is called" do
      trans = mock("transaction")
      repo = repository
      DataMapper::Transaction.should_receive(:new).once.with(repo).and_return(trans)
      repo.transaction.should == trans
    end
  end

  it "should provide persistance methods" do
    repository.should respond_to(:get)
    repository.should respond_to(:first)
    repository.should respond_to(:all)
    repository.should respond_to(:save)
    repository.should respond_to(:destroy)
  end

  it 'should call #create when #save is called on a new record' do
    repository = repository(:repository_spec)
    instance = Vegetable.new({:id => 1, :name => 'Potato'})

    @adapter.should_receive(:create).with(repository, instance).and_return(instance)

    repository.save(instance)
  end

  it 'should call #update when #save is called on an existing record' do
    repository = repository(:repository_spec)
    instance = Vegetable.new(:name => 'Potato')
    instance.instance_variable_set('@new_record', false)

    @adapter.should_receive(:update).with(repository, instance).and_return(instance)

    repository.save(instance)
  end

  it 'should provide default_name' do
    DataMapper::Repository.should respond_to(:default_name)
  end

  it 'should return :default for default_name' do
    DataMapper::Repository.default_name.should == :default
  end
  
  describe "#migrate!" do
    it "should call DataMapper::Migrator.migrate with itself as the repository argument" do
      repository = repository(:repository_spec)
      
      DataMapper::Migrator.should_receive(:migrate).with(repository)
      
      repository.migrate!
    end
  end
  
  describe "#auto_migrate!" do
    it "should call DataMapper::AutoMigrator.auto_migrate with itself as the repository argument" do
      repository = repository(:repository_spec)
      
      DataMapper::AutoMigrator.should_receive(:auto_migrate).with(repository)
      
      repository.auto_migrate!
    end
  end
  
  describe "#map" do
    it "should call @type_map.map with the arguments" do
      repository = repository(:repository_spec)
      repository.type_map.should_receive(:map).with(:type, :arg)
      
      repository.map(:type, :arg)
    end
  end
end
