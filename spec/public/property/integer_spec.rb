require 'spec_helper'

describe DataMapper::Property::Integer do
  before :all do
    @name          = :age
    @type          = described_class
    @load_as       = Integer
    @dump_as       = Integer
    @value         = 1
    @other_value   = 2
    @invalid_value = '1'
  end

  it_should_behave_like 'A public Property'

  describe '.options' do
    subject { described_class.options }

    it { should be_kind_of(Hash) }

    it { should eql(:load_as => @load_as) }
  end
end
