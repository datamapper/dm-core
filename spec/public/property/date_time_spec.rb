require 'spec_helper'

describe DataMapper::Property::DateTime do
  before :all do
    @name  = :created_at
    @type  = DataMapper::Property::DateTime
    @primitive = DateTime
    @value = DateTime.now
    @other_value = DateTime.now+15
    @invalid_value = 1
  end

  it_should_behave_like "A public Property"
end
