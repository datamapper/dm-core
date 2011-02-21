require 'spec_helper'

describe DataMapper::Property::String do
  before :all do
    @name  = :name
    @type  = DataMapper::Property::String
    @value = 'value'
    @other_value = 'return value'
    @invalid_value = 1
  end

  it_should_behave_like "A semipublic Property"
end
