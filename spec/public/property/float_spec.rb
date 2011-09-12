require 'spec_helper'

describe DataMapper::Property::Float do
  before :all do
    @name          = :rating
    @type          = described_class
    @load_as     = Float
    @value         = 0.1
    @other_value   = 0.2
    @invalid_value = '1'
  end

  it_should_behave_like 'A public Property'

  describe '.options' do
    subject { described_class.options }

    it { should be_kind_of(Hash) }

    it { should eql(:load_as => @load_as, :dump_as => @load_as, :coercion_method => :to_float, :precision => 10, :scale => nil) }
  end
end
