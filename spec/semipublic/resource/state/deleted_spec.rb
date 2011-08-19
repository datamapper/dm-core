require 'spec_helper'
describe DataMapper::Resource::PersistenceState::Deleted do
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

    @state = DataMapper::Resource::PersistenceState::Deleted.new(@resource)
  end

  after do
    @model.destroy!
  end

  describe '#commit' do
    subject { @state.commit }

    supported_by :all do
      it 'should return an Immutable state' do
        should eql(DataMapper::Resource::PersistenceState::Immutable.new(@resource))
      end

      it 'should delete the resource' do
        subject
        @model.get(*@resource.key).should be_nil
      end

      it 'should remove the resource from the identity map' do
        identity_map = @resource.repository.identity_map(@model)
        method(:subject).should change { identity_map.dup }.from(@resource.key => @resource).to({})
      end
    end
  end

  describe '#delete' do
    subject { @state.delete }

    supported_by :all do
      it 'should be a no-op' do
        should equal(@state)
      end
    end
  end

  describe '#get' do
    it_should_behave_like 'Resource::PersistenceState::Persisted#get'
  end

  describe '#set' do
    subject { @state.set(@key, @value) }

    supported_by :all do
      before do
        @key   = @model.properties[:name]
        @value = @key.get!(@resource)
      end

      it 'should raise an exception' do
        method(:subject).should raise_error(DataMapper::ImmutableDeletedError, 'Deleted resource cannot be modified')
      end
    end
  end
end
