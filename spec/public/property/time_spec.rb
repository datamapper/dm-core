require 'spec_helper'

describe DataMapper::Property::Time do
  before :all do
    @name  = :deleted_at
    @type  = DataMapper::Property::Time
    @primitive = Time
    @value = Time.now
    @other_value = Time.now+15
    @invalid_value = 1
  end

  it_should_behave_like "A public Property"
end
