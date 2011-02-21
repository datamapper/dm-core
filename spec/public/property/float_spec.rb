require 'spec_helper'

describe DataMapper::Property::Float do
  before :all do
    @name  = :rating
    @type  = DataMapper::Property::Float
    @primitive = Float
    @value = 0.1
    @other_value = 0.2
    @invalid_value = '1'
  end

  it_should_behave_like "A public Property"
end
