require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

# class methods
describe DataMapper::Query do
  before do
    class ::User
      include DataMapper::Resource

      property :name, String, :key => true
    end

    @repository = DataMapper::Repository.new(:default)
    @model      = User
    @options    = {}
  end

  it 'should respond to .new' do
    DataMapper::Query.should respond_to(:new)
  end

  describe '.new' do
    describe 'with a valid repository' do
      before do
        @return = @query = DataMapper::Query.new(@repository, @model, @options)
      end

      it 'should return a Query' do
        @return.should be_kind_of(DataMapper::Query)
      end

      it 'should set the repository' do
        @query.repository.should == @repository
      end
    end

    describe 'with a valid model' do
      before do
        @return = @query = DataMapper::Query.new(@repository, @model, @options)
      end

      it 'should return a Query' do
        @return.should be_kind_of(DataMapper::Query)
      end

      it 'should set the model' do
        @query.model.should == @model
      end
    end

    describe 'with valid options' do
      before do
        @return = @query = DataMapper::Query.new(@repository, @model, @options)
      end

      it 'should return a Query' do
        @return.should be_kind_of(DataMapper::Query)
      end

      it 'should have specs to make sure each option was set as expected'
    end

    describe 'with an invalid repository' do
      it 'should raise an exception' do
        lambda {
          DataMapper::Query.new('invalid', @model, @options)
        }.should raise_error(ArgumentError, '+repository+ should be DataMapper::Repository, but was String')
      end
    end

    describe 'with an invalid model' do
      it 'should raise an exception' do
        lambda {
          DataMapper::Query.new(@repository, 'invalid', @options)
        }.should raise_error(ArgumentError, '+model+ should be DataMapper::Model, but was String')
      end
    end

    describe 'with invalid options' do
      it 'should raise an exception' do
        lambda {
          DataMapper::Query.new(@repository, @model, 'invalid')
        }.should raise_error(ArgumentError, '+options+ should be Hash, but was String')
      end
    end
  end
end

# instance methods
describe DataMapper::Query do
  before do
    class ::User
      include DataMapper::Resource

      property :name, String, :key => true
    end

    @repository = DataMapper::Repository.new(:default)
    @model      = User
    @options    = {}
    @query      = DataMapper::Query.new(@repository, @model, @options)
  end

  it { @query.should respond_to(:==) }

  describe '#==' do
    describe 'when other is equal' do
      before do
        @return = @query == @query
      end

      it 'should return true' do
        @return.should be_true
      end
    end

    describe 'when other is equivalent' do
      before do
        @return = @query == @query.dup
      end

      it 'should return true' do
        @return.should be_true
      end
    end

    # TODO: iterate through all the Query attributes, and make one
    # different, and then check to make sure they are not equivalent
    describe 'when other is not an equivalent object' do
      before do
        @return = @query == @query.merge(:reload => true)
      end

      it 'should return false' do
        @return.should be_false
      end
    end

    describe 'when other is a different type of object that can be compared, and is equivalent' do
      it 'should return true'
    end

    describe 'when other is a different type of object that can be compared, and is not equivalent' do
      it 'should return false'
    end

    describe 'when other is a different type of object that cannot be compared' do
      before do
        @return = @query == 'invalid'
      end

      it 'should return false' do
        @return.should be_false
      end
    end
  end

  it { @query.should respond_to(:conditions) }

  describe '#conditions' do
    it 'should be awesome'
  end

  it { @query.should respond_to(:dup) }

  describe '#dup' do
    it 'should be awesome'
  end

  it { @query.should respond_to(:eql?) }

  describe '#eql?' do
    it 'should be awesome'
  end

  it { @query.should respond_to(:fields) }

  describe '#fields' do
    it 'should be awesome'
  end

  it { @query.should respond_to(:inspect) }

  describe '#inspect' do
    it 'should be awesome'
  end

  it { @query.should respond_to(:limit) }

  describe '#limit' do
    it 'should be awesome'
  end

  it { @query.should respond_to(:links) }

  describe '#links' do
    it 'should be awesome'
  end

  it { @query.should respond_to(:merge) }

  describe '#merge' do
    it 'should be awesome'
  end

  it { @query.should respond_to(:model) }

  describe '#model' do
    it 'should be awesome'
  end

  it { @query.should respond_to(:offset) }

  describe '#offset' do
    it 'should be awesome'
  end

  it { @query.should respond_to(:order) }

  describe '#order' do
    it 'should be awesome'
  end

  it { @query.should respond_to(:reload?) }

  describe '#reload?' do
    it 'should be awesome'
  end

  it { @query.should respond_to(:repository) }

  describe '#repository' do
    it 'should be awesome'
  end

  it { @query.should respond_to(:reverse) }

  describe '#reverse' do
    it 'should be awesome'
  end

  it { @query.should respond_to(:reverse!) }

  describe '#reverse!' do
    it 'should be awesome'
  end

  it { @query.should respond_to(:to_hash) }

  describe '#to_hash' do
    it 'should be awesome'
  end

  it { @query.should respond_to(:unique?) }

  describe '#unique?' do
    it 'should be awesome'
  end

  it { @query.should respond_to(:update) }

  describe '#update' do
    it 'should be awesome'
  end

  it { @query.should respond_to(:valid?) }

  describe '#valid?' do
    it 'should be awesome'
  end
end
