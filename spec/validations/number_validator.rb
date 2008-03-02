require File.dirname(__FILE__) + "/../spec_helper"

describe DataMapper::Validations::NumberValidator do
  before(:each) do
    @v = DataMapper::Validations::NumberValidator.new
  end

  it "should validate 'less than'" do
    @v < 10

    @v.errors_for(11).should_not be_empty
    @v.errors_for(10).should_not be_empty
    @v.errors_for(9).should be_empty
  end

  it "should validate 'less than or equals'" do
    @v <= 10

    @v.errors_for(11).should_not be_empty
    @v.errors_for(10).should be_empty
    @v.errors_for(9).should be_empty
  end

  it "should validate 'greater than'" do
    @v > 10

    @v.errors_for(11).should be_empty
    @v.errors_for(10).should_not be_empty
    @v.errors_for(9).should_not be_empty
  end

  it "should validate 'greater than or equals'" do
    @v >= 10

    @v.errors_for(11).should be_empty
    @v.errors_for(10).should be_empty
    @v.errors_for(9).should_not be_empty
  end

  it "should validate 'between' (inclusive)" do
    @v.between(1 .. 10)

    @v.errors_for(11).should_not be_empty
    @v.errors_for(0).should_not be_empty
    @v.errors_for(10).should be_empty
    @v.errors_for(1).should be_empty
    @v.errors_for(5).should be_empty
  end

  it "should validate 'between' (exclusive)" do
    @v.between(1 ... 10)

    @v.errors_for(11).should_not be_empty
    @v.errors_for(0).should_not be_empty
    @v.errors_for(10).should_not be_empty
    @v.errors_for(1).should be_empty
    @v.errors_for(5).should be_empty
  end
end
