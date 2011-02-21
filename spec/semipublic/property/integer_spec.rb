require 'spec_helper'

describe DataMapper::Property::Integer do
  before :all do
    @name  = :age
    @type  = DataMapper::Property::Integer
    @value = 1
    @other_value = 2
    @invalid_value = '1'
  end

  it_should_behave_like "A semipublic Property"

  describe '#typecast_to_primitive' do
    it 'returns same value if an integer' do
      @value = 24
      @property.typecast(@value).should equal(@value)
    end

    it 'returns integer representation of a zero string integer' do
      @property.typecast('0').should eql(0)
    end

    it 'returns integer representation of a positive string integer' do
      @property.typecast('24').should eql(24)
    end

    it 'returns integer representation of a negative string integer' do
      @property.typecast('-24').should eql(-24)
    end

    it 'returns integer representation of a zero string float' do
      @property.typecast('0.0').should eql(0)
    end

    it 'returns integer representation of a positive string float' do
      @property.typecast('24.35').should eql(24)
    end

    it 'returns integer representation of a negative string float' do
      @property.typecast('-24.35').should eql(-24)
    end

    it 'returns integer representation of a zero string float, with no leading digits' do
      @property.typecast('.0').should eql(0)
    end

    it 'returns integer representation of a positive string float, with no leading digits' do
      @property.typecast('.41').should eql(0)
    end

    it 'returns integer representation of a zero float' do
      @property.typecast(0.0).should eql(0)
    end

    it 'returns integer representation of a positive float' do
      @property.typecast(24.35).should eql(24)
    end

    it 'returns integer representation of a negative float' do
      @property.typecast(-24.35).should eql(-24)
    end

    it 'returns integer representation of a zero decimal' do
      @property.typecast(BigDecimal('0.0')).should eql(0)
    end

    it 'returns integer representation of a positive decimal' do
      @property.typecast(BigDecimal('24.35')).should eql(24)
    end

    it 'returns integer representation of a negative decimal' do
      @property.typecast(BigDecimal('-24.35')).should eql(-24)
    end

    [ Object.new, true, '00.0', '0.', '-.0', 'string' ].each do |value|
      it "does not typecast non-numeric value #{value.inspect}" do
        @property.typecast(value).should equal(value)
      end
    end
  end
end
