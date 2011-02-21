require 'spec_helper'

describe DataMapper::Property::Float do
  before :all do
    @name  = :rating
    @type  = DataMapper::Property::Float
    @value = 0.1
    @other_value = 0.2
    @invalid_value = '1'
  end

  it_should_behave_like "A semipublic Property"

  describe '#typecast_to_primitive' do
    it 'returns same value if a float' do
      @value = 24.0
      @property.typecast(@value).should equal(@value)
    end

    it 'returns float representation of a zero string integer' do
      @property.typecast('0').should eql(0.0)
    end

    it 'returns float representation of a positive string integer' do
      @property.typecast('24').should eql(24.0)
    end

    it 'returns float representation of a negative string integer' do
      @property.typecast('-24').should eql(-24.0)
    end

    it 'returns float representation of a zero string float' do
      @property.typecast('0.0').should eql(0.0)
    end

    it 'returns float representation of a positive string float' do
      @property.typecast('24.35').should eql(24.35)
    end

    it 'returns float representation of a negative string float' do
      @property.typecast('-24.35').should eql(-24.35)
    end

    it 'returns float representation of a zero string float, with no leading digits' do
      @property.typecast('.0').should eql(0.0)
    end

    it 'returns float representation of a positive string float, with no leading digits' do
      @property.typecast('.41').should eql(0.41)
    end

    it 'returns float representation of a zero integer' do
      @property.typecast(0).should eql(0.0)
    end

    it 'returns float representation of a positive integer' do
      @property.typecast(24).should eql(24.0)
    end

    it 'returns float representation of a negative integer' do
      @property.typecast(-24).should eql(-24.0)
    end

    it 'returns float representation of a zero decimal' do
      @property.typecast(BigDecimal('0.0')).should eql(0.0)
    end

    it 'returns float representation of a positive decimal' do
      @property.typecast(BigDecimal('24.35')).should eql(24.35)
    end

    it 'returns float representation of a negative decimal' do
      @property.typecast(BigDecimal('-24.35')).should eql(-24.35)
    end

    [ Object.new, true, '00.0', '0.', '-.0', 'string' ].each do |value|
      it "does not typecast non-numeric value #{value.inspect}" do
        @property.typecast(value).should equal(value)
      end
    end
  end
end
