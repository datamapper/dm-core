require 'spec_helper'

describe DataMapper::Property::Serial do
  before :all do
    @name  = :id
    @type  = DataMapper::Property::Serial
    @value = 1
    @other_value = 2
    @invalid_value = 'foo'
  end

  it_should_behave_like "A semipublic Property"
end
