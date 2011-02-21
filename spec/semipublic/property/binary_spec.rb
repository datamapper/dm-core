require 'spec_helper'

describe DataMapper::Property::Binary do
  before :all do
    @name  = :title
    @type  = DataMapper::Property::Binary
    @value = 'value'
    @other_value = 'return value'
    @invalid_value = 1
  end

  it_should_behave_like "A semipublic Property"
end
