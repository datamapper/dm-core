require 'spec_helper'
describe DataMapper::Resource::State::Clean do
  before :all do
    class ::Author
      include DataMapper::Resource

      property :id,     HugeInteger, :key => true, :default => 1
      property :name,   String
      property :active, Boolean,     :default => true
      property :coding, Boolean,     :default => true

      belongs_to :parent, self, :required => false
      has n, :children, self, :inverse => :parent
    end
    DataMapper.finalize

    @model = Author
  end

  before do
    @resource = @model.create(:name => 'Dan Kubb')

    @state = @resource.persisted_state
    @state.should be_kind_of(DataMapper::Resource::State::Clean)
  end

  after do
    @model.destroy!
  end

  [ :commit, :rollback ].each do |method|
    describe "##{method}" do
      subject { @state.send(method) }

      supported_by :all do
        it 'should be a no-op' do
          should equal(@state)
        end
      end
    end
  end

  describe '#delete' do
    subject { @state.delete }

    supported_by :all do
      it 'should return a Deleted state' do
        should eql(DataMapper::Resource::State::Deleted.new(@resource))
      end
    end
  end

  describe '#get' do
    it_should_behave_like 'Resource::State::Persisted#get'
  end

  describe '#set' do
    subject { @state.set(@key, @value) }

    supported_by :all do
      describe 'with attributes that make the resource dirty' do
        before do
          @key   = @model.properties[:name]
          @value = nil
        end

        it_should_behave_like 'A method that delegates to the superclass #set'

        it 'should return a Dirty state' do
          should eql(DataMapper::Resource::State::Dirty.new(@resource))
        end
      end

      describe 'with attributes that keep the resource clean' do
        before do
          @key   = @model.properties[:name]
          @value = 'Dan Kubb'
        end

        it_should_behave_like 'A method that does not delegate to the superclass #set'

        it 'should return a Clean state' do
          should equal(@state)
        end
      end
    end
  end
end
