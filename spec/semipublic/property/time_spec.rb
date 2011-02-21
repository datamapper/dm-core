require 'spec_helper'

describe DataMapper::Property::Time do
  before :all do
    @name  = :deleted_at
    @type  = DataMapper::Property::Time
    @value = Time.now
    @other_value = Time.now+15
    @invalid_value = 1
  end

  it_should_behave_like "A semipublic Property"

  describe '#typecast_to_primitive' do
    describe 'and value given as a hash with keys like :year, :month, etc' do
      it 'builds a Time instance from hash values' do
        result = @property.typecast(
          'year'  => '2006',
          'month' => '11',
          'day'   => '23',
          'hour'  => '12',
          'min'   => '0',
          'sec'   => '0'
        )

        result.should be_kind_of(Time)
        result.year.should  eql(2006)
        result.month.should eql(11)
        result.day.should   eql(23)
        result.hour.should  eql(12)
        result.min.should   eql(0)
        result.sec.should   eql(0)
      end
    end

    describe 'and value is a string' do
      it 'parses the string' do
        result = @property.typecast('22:24')
        result.hour.should eql(22)
        result.min.should eql(24)
      end
    end

    it 'does not typecast non-time values' do
      pending_if 'Time#parse is too permissive', RUBY_VERSION <= '1.9.1' do
        @property.typecast('not-time').should eql('not-time')
      end
    end
  end
end
