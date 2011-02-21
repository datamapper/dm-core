require 'spec_helper'

describe DataMapper::Property::Integer do
  before :all do
    @name  = :age
    @type  = DataMapper::Property::Integer
    @primitive = Integer
    @value = 1
    @other_value = 2
    @invalid_value = '1'
  end

  it_should_behave_like "A public Property"
end
