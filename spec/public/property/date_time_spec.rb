require 'spec_helper'

describe DataMapper::Property::DateTime do
  before :all do
    @name          = :created_at
    @type          = described_class
    @load_as     = DateTime
    @value         = DateTime.now
    @other_value   = DateTime.now + 15
    @invalid_value = 1
  end

  it_should_behave_like 'A public Property'

  describe '.options' do
    subject { described_class.options }

    it { should be_kind_of(Hash) }

    it { should eql(:load_as => @load_as, :dump_as => @load_as, :coercion_method => :to_datetime) }
  end
end
