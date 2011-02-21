require 'spec_helper'

describe DataMapper::Property::Text do
  before :all do
    @name  = :title
    @type  = DataMapper::Property::Text
    @value = 'value'
    @other_value = 'return value'
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
end
