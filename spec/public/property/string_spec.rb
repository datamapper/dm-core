require 'spec_helper'

describe DataMapper::Property::String do
  before :all do
    @name          = :name
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

    it { should eql(:primitive => @primitive, :length => 50) }
  end
end
