require 'spec_helper'

describe DataMapper::Resource::PersistenceState do
  before :all do
    class ::Author
      include DataMapper::Resource

      property :id,      Serial
      property :name,    String
      property :private, Boolean, :accessor => :private

      belongs_to :parent, self, :required => false
    end

    DataMapper.finalize

    @model = Author
  end

  before do
    @resource = @model.new(:name => 'Dan Kubb')

    @state = DataMapper::Resource::PersistenceState.new(@resource)
  end

  describe '.new' do
    subject { DataMapper::Resource::PersistenceState.new(@resource) }

    it { should be_kind_of(DataMapper::Resource::PersistenceState) }
  end

  describe '#==' do
    subject { @state == @other }

    supported_by :all do
      describe 'with the same class and resource' do
        before do
          @other = DataMapper::Resource::PersistenceState.new(@resource)
        end

        it { should be(true) }

        it 'should be symmetric' do
          should == (@other == @state)
        end
      end

      describe 'with the same class and different resource' do
        before do
          @other = DataMapper::Resource::PersistenceState.new(@model.new)
        end

        it { should be(false) }

        it 'should be symmetric' do
          should == (@other == @state)
        end
      end

      describe 'with a different class and the same resource' do
        before do
          @other = DataMapper::Resource::PersistenceState::Clean.new(@resource)
        end

        it 'should be true for a subclass' do
          should be(true)
        end

        it 'should be symmetric' do
          should == (@other == @state)
        end
      end

      describe 'with a different class and different resource' do
        before do
          @other = DataMapper::Resource::PersistenceState::Clean.new(@model.new)
        end

        it { should be(false) }

        it 'should be symmetric' do
          should == (@other == @state)
        end
      end
    end
  end

  [ :commit, :delete, :rollback ].each do |method|
    describe "##{method}" do
      subject { @state.send(method) }

      it 'should raise an exception' do
        method(:subject).should raise_error(NotImplementedError, "DataMapper::Resource::PersistenceState##{method} should be implemented")
      end
    end
  end

  describe '#eql?' do
    subject { @state.eql?(@other) }

    supported_by :all do
      describe 'with the same class and resource' do
        before do
          @other = DataMapper::Resource::PersistenceState.new(@resource)
        end

        it { should be(true) }

        it 'should be symmetric' do
          should == @other.eql?(@state)
        end
      end

      describe 'with the same class and different resource' do
        before do
          @other = DataMapper::Resource::PersistenceState.new(@model.new)
        end

        it { should be(false) }

        it 'should be symmetric' do
          should == @other.eql?(@state)
        end
      end

      describe 'with a different class and the same resource' do
        before do
          @other = DataMapper::Resource::PersistenceState::Clean.new(@resource)
        end

        it { should be(false) }

        it 'should be symmetric' do
          should == @other.eql?(@state)
        end
      end

      describe 'with a different class and different resource' do
        before do
          @other = DataMapper::Resource::PersistenceState::Clean.new(@model.new)
        end

        it { should be(false) }

        it 'should be symmetric' do
          should == @other.eql?(@state)
        end
      end
    end
  end

  describe '#get' do
    subject { @state.get(@key) }

    describe 'with a Property subject' do
      before do
        @key = @model.properties[:name]
      end

      it 'should return the value' do
        should == 'Dan Kubb'
      end
    end

    describe 'with a Relationship subject' do
      supported_by :all do
        before do
          # set the association
          @resource.parent = @resource

          @key = @model.relationships[:parent]
        end

        it 'should return the association' do
          should == @resource
        end
      end
    end
  end

  describe '#hash' do
    subject { @state.hash }

    it { should == @state.class.hash ^ @resource.hash }
  end

  describe '#resource' do
    subject { @state.resource }

    it 'should return the resource' do
      should equal(@resource)
    end
  end

  describe '#set' do
    subject { @state.set(@key, @value) }

    describe 'with a Property subject' do
      before do
        @key   = @model.properties[:name]
        @value = 'John Doe'
      end

      it 'should return a state object' do
        should be_kind_of(DataMapper::Resource::PersistenceState)
      end

      it 'should change the object attributes' do
        method(:subject).should change(@resource, :attributes).from(:name => 'Dan Kubb').to(:name => 'John Doe')
      end
    end

    describe 'with a Relationship subject' do
      supported_by :all do
        before do
          @key   = @model.relationships[:parent]
          @value = @resource
        end

        it 'should return a state object' do
          should be_kind_of(DataMapper::Resource::PersistenceState)
        end

        it 'should change the object relationship' do
          method(:subject).should change(@resource, :parent).from(nil).to(@resource)
        end
      end
    end
  end
end
