require 'spec_helper'

describe DataMapper::Property::Text do
  before :all do
    @name          = :title
    @type          = described_class
    @primitive     = String
    @value         = 'value'
    @other_value   = 'return value'
    @invalid_value = 1
  end

  it_should_behave_like 'A public Property'

  describe '.options' do
    subject { described_class.options }

    it { should be_kind_of(Hash) }

    it { should eql(:primitive => @primitive, :length => 65535, :lazy => true) }
  end

  describe 'migration with an index' do
    supported_by :all do
      before do
        Object.send(:remove_const, :Foo) if Object.const_defined?(:Foo)
        @model = DataMapper::Model.new('Foo') do
          storage_names[:default] = 'anonymous'

          property :id,   DataMapper::Property::Serial
          property :body, DataMapper::Property::Text, :index => true
        end
      end

      it 'should allow a migration' do
        lambda {
          @model.auto_migrate!
        }.should_not raise_error(DataObjects::SyntaxError)
      end
    end
  end if defined?(DataObjects::SyntaxError)

  describe 'migration with a unique index' do
    supported_by :all do
      before do

        Object.send(:remove_const, :Foo) if Object.const_defined?(:Foo)
        @model = DataMapper::Model.new('Foo') do
          storage_names[:default] = 'anonymous'

          property :id,   DataMapper::Property::Serial
          property :body, DataMapper::Property::Text, :unique_index => true
        end
      end

      it 'should allow a migration' do
        lambda {
          @model.auto_migrate!
        }.should_not raise_error(DataObjects::SyntaxError)
      end
    end
  end if defined?(DataObjects::SyntaxError)
end
