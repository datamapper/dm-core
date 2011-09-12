require 'spec_helper'

describe DataMapper::Property::Time do
  before :all do
    @name          = :deleted_at
    @type          = described_class
    @load_as     = Time
    @value         = Time.now
    @other_value   = Time.now + 15
    @invalid_value = 1
  end

  it_should_behave_like 'A public Property'

  describe '.options' do
    subject { described_class.options }

    it { should be_kind_of(Hash) }

    it { should eql(:load_as => @load_as, :dump_as => @load_as, :coercion_method => :to_time) }
  end
end
