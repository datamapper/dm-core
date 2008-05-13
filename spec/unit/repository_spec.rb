require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

class Vegetable
  include DataMapper::Resource

  property :id, Integer, :serial => true
  property :name, String
end

class Fruit
  include DataMapper::Resource

  property :id, Integer, :key => true
  property :name, String
end

class Grain
  include DataMapper::Resource

  property :id, Integer, :key => true
  property :name, String, :default => 'wheat'
end

describe DataMapper::Repository do

  before do
    @adapter = DataMapper::Repository.adapters[:mock]
  end

  describe "managing transactions" do
    it "should create a new Transaction with itself as argument when #transaction is called" do
      trans = mock("transaction")
      repo = repository
      DataMapper::Transaction.should_receive(:new).once.with(repo).and_return(trans)
      repo.transaction.should == trans
    end
  end

  it '.storage_exists? should whether or not the repository exists' do
    repository.should respond_to(:storage_exists?)
    repository.storage_exists?(:vegetable).should == true
  end

  it "should provide persistance methods" do
    repository.should respond_to(:get)
    repository.should respond_to(:first)
    repository.should respond_to(:all)
    repository.should respond_to(:save)
    repository.should respond_to(:destroy)
  end

  describe '#save' do
    describe 'with a new resource' do
      it 'should create when dirty' do
        repository = repository(:mock)
        instance = Vegetable.new({:id => 1, :name => 'Potato'})

        instance.should be_dirty
        instance.should be_new_record

        @adapter.should_receive(:create).with(repository, instance).and_return(instance)

        repository.save(instance)
      end

      it 'should create when non-dirty, and it has a serial key' do
        repository = repository(:mock)
        instance = Vegetable.new

        instance.should_not be_dirty
        instance.should be_new_record
        instance.class.key.any? { |p| p.serial? }.should be_true

        @adapter.should_receive(:create).with(repository, instance).once.and_return(instance)

        repository.save(instance).should be_true
      end

      it 'should not create when non-dirty, and is has a non-serial key' do
        repository = repository(:mock)
        instance = Fruit.new

        instance.should_not be_dirty
        instance.should be_new_record
        instance.class.key.any? { |p| p.serial? }.should_not be_true

        @adapter.should_not_receive(:create)

        repository.save(instance).should be_false
      end

      it 'should set defaults before create' do
        repository = repository(:mock)
        instance = Grain.new

        instance.should_not be_dirty
        instance.should be_new_record
        instance.instance_variable_get('@name').should be_nil

        @adapter.should_receive(:create).with(repository, instance).and_return(instance)

        repository.save(instance)

        instance.instance_variable_get('@name').should == 'wheat'
      end
    end

    describe 'with an existing resource' do
      it 'should update when dirty' do
        repository = repository(:mock)
        instance = Vegetable.new(:name => 'Potato')
        instance.instance_variable_set('@new_record', false)

        instance.should be_dirty
        instance.should_not be_new_record

        @adapter.should_receive(:update).with(repository, instance).and_return(instance)

        repository.save(instance)
      end

      it 'should not update when non-dirty' do
        repository = repository(:mock)
        instance = Vegetable.new
        instance.instance_variable_set('@new_record', false)

        instance.should_not be_dirty
        instance.should_not be_new_record

        @adapter.should_not_receive(:update)

        repository.save(instance)
      end
    end
  end

  it 'should provide default_name' do
    DataMapper::Repository.should respond_to(:default_name)
  end

  it 'should return :default for default_name' do
    DataMapper::Repository.default_name.should == :default
  end

  describe "#migrate!" do
    it "should call DataMapper::Migrator.migrate with itself as the repository argument" do
      repository = repository(:mock)

      DataMapper::Migrator.should_receive(:migrate).with(repository.name)

      repository.migrate!
    end
  end

  describe "#auto_migrate!" do
    it "should call DataMapper::AutoMigrator.auto_migrate with itself as the repository argument" do
      repository = repository(:mock)

      DataMapper::AutoMigrator.should_receive(:auto_migrate).with(repository.name)

      repository.auto_migrate!
    end
  end

  describe "#map" do
    it "should call @type_map.map with the arguments" do
      repository = repository(:mock)
      repository.type_map.should_receive(:map).with(:type, :arg)

      repository.map(:type, :arg)
    end
  end
end
