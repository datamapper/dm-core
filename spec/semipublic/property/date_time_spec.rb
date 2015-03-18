require 'spec_helper'

describe DataMapper::Property::DateTime do
  before :all do
    @name          = :created_at
    @type          = described_class
    @value         = DateTime.now
    @other_value   = DateTime.now + 15
    @invalid_value = 1
  end

  it_should_behave_like 'A semipublic Property'

  describe '#typecast_to_primitive' do
    describe 'and value given as a hash with keys like :year, :month, etc' do
      it 'builds a DateTime instance from hash values' do
        result = @property.typecast(
          'year'  => '2006',
          'month' => '11',
          'day'   => '23',
          'hour'  => '12',
          'min'   => '0',
          'sec'   => '0'
        )

        result.should be_kind_of(DateTime)
        result.year.should eql(2006)
        result.month.should eql(11)
        result.day.should eql(23)
        result.hour.should eql(12)
        result.min.should eql(0)
        result.sec.should eql(0)
      end
    end

    describe 'and value is a string' do
      it 'parses the string' do
        @property.typecast('Dec, 2006').month.should == 12
      end
    end

    it 'does not typecast non-datetime values' do
      @property.typecast('not-datetime').should eql('not-datetime')
    end
  end
end
