require 'spec_helper'

describe DataMapper::Property::Boolean do
  before :all do
    @name  = :active
    @type  = DataMapper::Property::Boolean
    @value = true
    @other_value = false
    @invalid_value = 1
  end

  it_should_behave_like "A semipublic Property"

  describe '#load' do
    before :all do
      @value = mock('value')
    end

    subject { @property.load(@value) }

    before do
      @property = @type.new(@model, @name)
    end

    it 'should delegate to #type.load' do
      return_value = mock('return value')
      @property.should_receive(:load).with(@value).and_return(return_value)
      should == return_value
    end
  end

  describe '#valid?' do
    [ true, false ].each do |value|
      it "returns true when value is #{value.inspect}" do
        @property.valid?(value).should be(true)
      end
    end

    [ 'true', 'TRUE', '1', 1, 't', 'T', 'false', 'FALSE', '0', 0, 'f', 'F' ].each do |value|
      it "returns false for #{value.inspect}" do
        @property.valid?(value).should be(false)
      end
    end
  end

  describe '#typecast_to_primitive' do
    [ true, 'true', 'TRUE', '1', 1, 't', 'T' ].each do |value|
      it "returns true when value is #{value.inspect}" do
        @property.typecast(value).should be(true)
      end
    end

    [ false, 'false', 'FALSE', '0', 0, 'f', 'F' ].each do |value|
      it "returns false when value is #{value.inspect}" do
        @property.typecast(value).should be(false)
      end
    end

    [ 'string', 2, 1.0, BigDecimal('1.0'), DateTime.now, Time.now, Date.today, Class, Object.new, ].each do |value|
      it "does not typecast value #{value.inspect}" do
        @property.typecast(value).should equal(value)
      end
    end
  end
end
