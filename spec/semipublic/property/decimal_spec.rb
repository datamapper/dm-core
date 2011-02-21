require 'spec_helper'

describe DataMapper::Property::Decimal do
  before :all do
    @name          = :rate
    @type          = DataMapper::Property::Decimal
    @options       = { :precision => 5, :scale => 2 }
    @value         = BigDecimal('1.0')
    @other_value   = BigDecimal('2.0')
    @invalid_value = true
  end

  it_should_behave_like "A semipublic Property"

  describe '#typecast_to_primitive' do
    it 'returns same value if a decimal' do
      @value = BigDecimal('24.0')
      @property.typecast(@value).should equal(@value)
    end

    it 'returns decimal representation of a zero string integer' do
      @property.typecast('0').should eql(BigDecimal('0.0'))
    end

    it 'returns decimal representation of a positive string integer' do
      @property.typecast('24').should eql(BigDecimal('24.0'))
    end

    it 'returns decimal representation of a negative string integer' do
      @property.typecast('-24').should eql(BigDecimal('-24.0'))
    end

    it 'returns decimal representation of a zero string float' do
      @property.typecast('0.0').should eql(BigDecimal('0.0'))
    end

    it 'returns decimal representation of a positive string float' do
      @property.typecast('24.35').should eql(BigDecimal('24.35'))
    end

    it 'returns decimal representation of a negative string float' do
      @property.typecast('-24.35').should eql(BigDecimal('-24.35'))
    end

    it 'returns decimal representation of a zero string float, with no leading digits' do
      @property.typecast('.0').should eql(BigDecimal('0.0'))
    end

    it 'returns decimal representation of a positive string float, with no leading digits' do
      @property.typecast('.41').should eql(BigDecimal('0.41'))
    end

    it 'returns decimal representation of a zero integer' do
      @property.typecast(0).should eql(BigDecimal('0.0'))
    end

    it 'returns decimal representation of a positive integer' do
      @property.typecast(24).should eql(BigDecimal('24.0'))
    end

    it 'returns decimal representation of a negative integer' do
      @property.typecast(-24).should eql(BigDecimal('-24.0'))
    end

    it 'returns decimal representation of a zero float' do
      @property.typecast(0.0).should eql(BigDecimal('0.0'))
    end

    it 'returns decimal representation of a positive float' do
      @property.typecast(24.35).should eql(BigDecimal('24.35'))
    end

    it 'returns decimal representation of a negative float' do
      @property.typecast(-24.35).should eql(BigDecimal('-24.35'))
    end

    [ Object.new, true, '00.0', '0.', '-.0', 'string' ].each do |value|
      it "does not typecast non-numeric value #{value.inspect}" do
        @property.typecast(value).should equal(value)
      end
    end
  end
end
