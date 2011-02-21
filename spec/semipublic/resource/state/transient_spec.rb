require 'spec_helper'
describe DataMapper::Resource::State::Transient do
  before :all do
    class ::Author
      include DataMapper::Resource

      property :id,          Serial
      property :name,        String
      property :age,         Integer
      property :description, Text,    :default => lambda { |resource, property| resource.name }
      property :active,      Boolean, :default => true
      property :coding,      Boolean, :default => true

      belongs_to :parent, self, :required => false
      has n, :children, self, :inverse => :parent

      belongs_to :with_default, self, :required => false, :default => proc { first(:name => 'John Doe') }
    end

    DataMapper.finalize

    @model = Author
  end

  before do
    @parent   = @model.create(:name => 'John Doe')
    @resource = @model.new(:name => 'Dan Kubb', :coding => false, :parent => @parent)

    @state = @resource.persisted_state
    @state.should be_kind_of(DataMapper::Resource::State::Transient)
  end

  after do
    @model.destroy!
  end

  describe '#commit' do
    subject { @state.commit }

    supported_by :all do
      it 'should return the expected Clean state' do
        should eql(DataMapper::Resource::State::Clean.new(@resource))
      end

      it 'should set the serial property' do
        method(:subject).should change(@resource, :id).from(nil)
      end

      it 'should set the child key if the parent key changes' do
        # SqlServer does not allow updating IDENTITY columns.
        if defined?(DataMapper::Adapters::SqlserverAdapter) &&
           @adapter.kind_of?(DataMapper::Adapters::SqlserverAdapter)
          return
        end

        original_id = @parent.id
        @parent.update(:id => 42).should be(true)
        method(:subject).should change(@resource, :parent_id).from(original_id).to(42)
      end

      it 'should set default values' do
        method(:subject).should change { @model.relationships[:with_default].get!(@resource) }.from(nil).to(@parent)
      end

      it 'should not set default values when they are already set' do
        method(:subject).should_not change(@resource, :coding)
      end

      it 'should create the resource' do
        subject
        @model.get(*@resource.key).should == @resource
      end

      it 'should reset original attributes' do
        original_attributes = {
          @model.properties[:name]      => nil,
          @model.properties[:coding]    => nil,
          @model.properties[:parent_id] => nil,
          @model.relationships[:parent] => nil,
        }

        expect do
          @resource.persisted_state = subject
        end.should change { @resource.original_attributes.dup }.from(original_attributes).to({})
      end

      it 'should add the resource to the identity map' do
        DataMapper.repository do |repository|
          identity_map = repository.identity_map(@model)
          identity_map.should be_empty
          subject
          identity_map.should == { @parent.key => @parent, @resource.key => @resource }
        end
      end
    end
  end

  [ :delete, :rollback ].each do |method|
    describe "##{method}" do
      subject { @state.send(method) }

      supported_by :all do
        it 'should be a no-op' do
          should equal(@state)
        end
      end
    end
  end

  describe '#get' do
    subject { @state.get(@key) }

    supported_by :all do
      describe 'with a set value' do
        before do
          @key = @model.properties[:coding]
          @key.should be_loaded(@resource)
        end

        it 'should return value' do
          should be(false)
        end

        it 'should be idempotent' do
          should equal(subject)
        end
      end

      describe 'with an unset value and no default value' do
        before do
          @key = @model.properties[:age]
          @key.should_not be_loaded(@resource)
          @key.should_not be_default
        end

        it 'should return nil' do
          should be_nil
        end

        it 'should be idempotent' do
          should equal(subject)
        end
      end

      describe 'with an unset value and a default value' do
        before do
          @key = @model.properties[:description]
          @key.should_not be_loaded(@resource)
          @key.should be_default
        end

        it 'should return the name' do
          should == 'Dan Kubb'
        end

        it 'should be idempotent' do
          should equal(subject)
        end
      end
    end
  end
end
