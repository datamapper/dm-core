require 'spec_helper'

describe DataMapper::Property::Boolean do
  before :all do
    @name  = :active
    @type  = DataMapper::Property::Boolean
    @primitive = TrueClass
    @value = true
    @other_value = false
    @invalid_value = 1
  end

  it_should_behave_like "A public Property"
end
