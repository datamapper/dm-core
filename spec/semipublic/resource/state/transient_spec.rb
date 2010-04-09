require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', 'spec_helper'))

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
    end

    @model = Author
  end

  before do
    @resource = @model.new(:name => 'Dan Kubb', :coding => false)

    @state = @resource.persisted_state
    @state.should be_kind_of(DataMapper::Resource::State::Transient)
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

      it 'should set default values' do
        method(:subject).should change { @model.properties[:active].get!(@resource) }.from(nil).to(true)
      end

      it 'should not set default values when they are already set' do
        method(:subject).should_not change(@resource, :coding)
      end

      it 'should create the resource' do
        subject
        @model.get(*@resource.key).should == @resource
      end

      it 'should reset original attributes' do
        expect do
          @resource.persisted_state = subject
        end.should change { @resource.original_attributes.dup }.from(@model.properties[:name] => nil, @model.properties[:coding] => nil).to({})
      end

      it 'should add the resource to the identity map' do
        DataMapper.repository do |repository|
          identity_map = repository.identity_map(@model)
          identity_map.should be_empty
          subject
          identity_map.should == { @resource.key => @resource }
        end
      end
    end
  end

  [ :delete, :rollback ].each do |method|
    describe "##{method}" do
      subject { @state.send(method) }

      it 'should be a no-op' do
        should equal(@state)
      end
    end
  end

  describe '#get' do
    subject { @state.get(@key) }

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
