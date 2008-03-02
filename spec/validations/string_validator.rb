require File.dirname(__FILE__) + "/../spec_helper"

describe DataMapper::Validations::StringValidator do
  before(:each) do
    @v = DataMapper::Validations::StringValidator.new
  end

  it "should validate 'matches'" # do
  #   @v.matches /aabb/

  #   @v.errors_for("cde").should_not be_empty
  #   @v.errors_for("aabbb").should be_empty
  # end
end
