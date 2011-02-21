require 'spec_helper'

describe DataMapper::Property::Date do
  before :all do
    @name  = :created_on
    @type  = DataMapper::Property::Date
    @value = Date.today
    @other_value = Date.today+1
    @invalid_value = 1
  end

  it_should_behave_like "A semipublic Property"

  describe '#typecast_to_primitive' do
    describe 'and value given as a hash with keys like :year, :month, etc' do
      it 'builds a Date instance from hash values' do
        result = @property.typecast(
          'year'  => '2007',
          'month' => '3',
          'day'   => '25'
        )

        result.should be_kind_of(Date)
        result.year.should eql(2007)
        result.month.should eql(3)
        result.day.should eql(25)
      end
    end

    describe 'and value is a string' do
      it 'parses the string' do
        result = @property.typecast('Dec 20th, 2006')
        result.month.should == 12
        result.day.should == 20
        result.year.should == 2006
      end
    end

    it 'does not typecast non-date values' do
      @property.typecast('not-date').should eql('not-date')
    end
  end
end
