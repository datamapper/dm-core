require 'spec_helper'

describe DataMapper::Property::Date do
  before :all do
    @name  = :created_on
    @type  = DataMapper::Property::Date
    @primitive = Date
    @value = Date.today
    @other_value = Date.today+1
    @invalid_value = 1
  end

  it_should_behave_like "A public Property"
end
