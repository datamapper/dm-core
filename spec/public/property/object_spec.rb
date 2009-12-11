require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'spec_helper'))

describe DataMapper::Property, 'Object type' do
  before :all do
    module ::Blog
      class Article
        include DataMapper::Resource

        property :id,    Serial
        property :title, String
        property :meta,  Object, :required => true
      end
    end

    @model    = Blog::Article
    @property = @model.properties[:meta]
  end

  subject { @property }

  it { should respond_to(:typecast) }

  describe '#typecast' do
    before do
      @value = { 'lang' => 'en_CA' }
    end

    subject { @property.typecast(@value) }

    it { should equal(@value) }
  end

  it { should respond_to(:value) }

  describe '#value' do
    describe 'with a value' do
      before do
        @value = { 'lang' => 'en_CA' }
      end

      subject { @property.value(@value) }

      it { @property.type.load(subject, @property).should == @value }
    end

    describe 'with nil' do
      subject { @property.value(nil) }

      it { should be_nil }
    end
  end

  it { should respond_to(:valid?) }

  describe '#valid?' do
    describe 'with a valid primitive' do
      subject { @property.valid?('lang' => 'en_CA') }

      it { should be_true }
    end

    describe 'with nil and property is not required' do
      before do
        @property = @model.property(:meta, Object, :required => false)
      end

      subject { @property.valid?(nil) }

      it { should be_true }
    end

    describe 'with nil and property is required' do
      subject { @property.valid?(nil) }

      it { should be_false }
    end

    describe 'with nil and property is required, but validity is negated' do
      subject { @property.valid?(nil, true) }

      it { should be_true }
    end
  end

  describe 'persistable' do
    supported_by :all do
      before :all do
        @do_adapter = defined?(DataMapper::Adapters::DataObjectsAdapter) && @adapter.kind_of?(DataMapper::Adapters::DataObjectsAdapter)
      end

      before :all do
        @resource = @model.create(:title => 'Test', :meta => { 'lang' => 'en_CA' })
      end

      subject { @resource.reload.meta }

      it 'should load the correct value' do
        pending_if 'Fix adapters to use different serialization methods', !@do_adapter do
          pending_if 'Fix DO adapter to send String for Text primitive', !!(RUBY_PLATFORM =~ /java/) do
            should == { 'lang' => 'en_CA' }
          end
        end
      end
    end
  end
end
