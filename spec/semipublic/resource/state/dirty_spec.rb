require 'spec_helper'
describe DataMapper::Resource::PersistenceState::Dirty do
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
    @parent = @model.create(:name => 'Jane Doe')

    @resource = @model.create(:id => 2, :name => 'Dan Kubb', :parent => @parent)
    @resource.attributes = { :name => 'John Doe' }

    @state = @resource.persistence_state
    @state.should be_kind_of(DataMapper::Resource::PersistenceState::Dirty)
  end

  after do
    @model.destroy!
  end

  describe '#commit' do
    subject { @state.commit }

    supported_by :all do
      context 'with valid attributes' do
        let(:state) { @state }

        before do
          @new_id = @resource.id = @resource.id.succ
        end

        it 'should return a Clean state' do
          should eql(DataMapper::Resource::PersistenceState::Clean.new(@resource))
        end

        it 'should set the child key if the parent key changes' do
          original_id = @parent.id
          @parent.update(:id => 42).should be(true)
          method(:subject).should change(@resource, :parent_id).from(original_id).to(42)
        end

        it 'should update the resource' do
          subject
          @model.get!(*@resource.key).should == @resource
        end

        it 'should update the resource to the identity map if the key changed' do
          identity_map = @resource.repository.identity_map(@model)
          identity_map.should == { @resource.key => @resource }
          subject
          identity_map.should == { [ @new_id ] => @resource }
        end
      end

      context 'with invalid attributes' do
        before do
          @resource.coding = 'yes'
        end

        it { should equal(@state) }

        it 'should update the resource to the identity map if the key changed' do
          method(:subject).should_not change { @resource.repository.identity_map(@model).dup }
        end
      end
    end
  end

  describe '#delete' do
    subject { @state.delete }

    supported_by :all do
      before do
        @resource.children = [ @resource.parent = @resource ]
      end

      it_should_behave_like 'It resets resource state'

      it 'should return a Deleted state' do
        should eql(DataMapper::Resource::PersistenceState::Deleted.new(@resource))
      end
    end
  end

  describe '#get' do
    before do
      @loaded_value = 'John Doe'
    end

    it_should_behave_like 'Resource::PersistenceState::Persisted#get'
  end

  describe '#rollback' do
    subject { @state.rollback }

    supported_by :all do
      before do
        @resource.children = [ @resource.parent = @resource ]
      end

      it_should_behave_like 'It resets resource state'

      it 'should return a Clean state' do
        should eql(DataMapper::Resource::PersistenceState::Clean.new(@resource))
      end
    end
  end

  describe '#set' do
    subject { @state.set(@key, @value) }

    supported_by :all do
      describe 'with attributes that keep the resource dirty' do
        before do
          @key   = @model.properties[:id]
          @value = @key.get!(@resource)
        end

        it_should_behave_like 'A method that delegates to the superclass #set'

        it 'should return a Dirty state' do
          should equal(@state)
        end

        its(:original_attributes) { should == { @model.properties[:name] => 'Dan Kubb' } }
      end

      describe 'with attributes that make the resource clean' do
        before do
          @key   = @model.properties[:name]
          @value = 'Dan Kubb'
        end

        it_should_behave_like 'A method that delegates to the superclass #set'

        it 'should return a Clean state' do
          should eql(DataMapper::Resource::PersistenceState::Clean.new(@resource))
        end
      end
    end
  end
end
