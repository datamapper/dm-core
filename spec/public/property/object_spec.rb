require 'spec_helper'

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

    DataMapper.finalize
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

  it { should respond_to(:dump) }

  describe '#dump' do
    describe 'with a value' do
      before do
        @value = { 'lang' => 'en_CA' }
      end

      subject { @property.dump(@value) }

      it { @property.load(subject).should == @value }
    end

    describe 'with nil' do
      subject { @property.dump(nil) }

      it { should be_nil }
    end
  end

  it { should respond_to(:valid?) }

  describe '#valid?' do
    describe 'with a valid primitive' do
      subject { @property.valid?('lang' => 'en_CA') }

      it { should be(true) }
    end

    describe 'with nil and property is not required' do
      before do
        @property = @model.property(:meta, Object, :required => false)
      end

      subject { @property.valid?(nil) }

      it { should be(true) }
    end

    describe 'with nil and property is required' do
      subject { @property.valid?(nil) }

      it { should be(false) }
    end

    describe 'with nil and property is required, but validity is negated' do
      subject { @property.valid?(nil, true) }

      it { should be(true) }
    end
  end

  describe 'persistable' do
    supported_by :all do
      before :all do
        @resource = @model.create(:title => 'Test', :meta => { 'lang' => 'en_CA' })
      end

      subject { @resource.reload.meta }

      it 'should load the correct value' do
        should == { 'lang' => 'en_CA' }
      end
    end
  end
end
