require 'spec_helper'

describe DataMapper::Property::Date do
  before :all do
    @name          = :created_on
    @type          = described_class
    @load_as     = Date
    @value         = Date.today
    @other_value   = Date.today + 1
    @invalid_value = 1
  end

  it_should_behave_like 'A public Property'

  describe '.options' do
    subject { described_class.options }

    it { should be_kind_of(Hash) }

    it { should eql(:load_as => @load_as) }
  end
end
