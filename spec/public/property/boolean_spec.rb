require 'spec_helper'

describe DataMapper::Property::Boolean do
  before :all do
    @name          = :active
    @type          = described_class
    @primitive     = TrueClass
    @value         = true
    @other_value   = false
    @invalid_value = 1
  end

  it_should_behave_like 'A public Property'

  describe '.options' do
    subject { described_class.options }

    it { should be_kind_of(Hash) }

    it { should eql(:primitive => @primitive) }
  end
end
