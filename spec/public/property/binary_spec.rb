require 'spec_helper'

describe DataMapper::Property::Binary do
  before :all do
    @name          = :title
    @type          = described_class
    @load_as       = String
    @value         = 'value'
    @other_value   = 'return value'
    @invalid_value = 1
  end

  it_should_behave_like 'A public Property'

  describe '.options' do
    subject { described_class.options }

    it { should eql(:load_as => @load_as, :length => 50) }
  end

  if RUBY_VERSION >= "1.9"
    describe 'encoding' do
      let(:model) do
        Class.new do
          include ::DataMapper::Resource
          property :bin_data, ::DataMapper::Property::Binary
        end
      end

      it 'should always dump with BINARY' do
        model.bin_data.dump("foo".freeze).encoding.names.should include("BINARY")
      end

      it 'should always load with BINARY' do
        model.bin_data.load("foo".freeze).encoding.names.should include("BINARY")
      end
    end

    describe '.options' do
      subject { described_class.options }

      it { should eql(:load_as => @load_as, :length => 50) }
    end
  end
end
