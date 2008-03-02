require File.dirname(__FILE__) + "/../spec_helper"

describe DataMapper::Types::String do
  it "should look like a String" do
    DataMapper::Types::String.new("duh").should be_a_kind_of(String)
  end

  it "should answer for :string" do
    DataMapper::Types::TYPE_MAP[:string].should == DataMapper::Types::String
  end

  it "should be ready to replace Strings" do
    DataMapper::Types::TYPE_MAP[String].should == DataMapper::Types::String
  end

  describe "with validations" do

    it "should catch length errors" do
      nval = mock("length validator")
      nval.should_receive(:<)

      DataMapper::Validations::NumberValidator.should_receive(:new).and_return(nval)

      class T < DataMapper::Types::String
        length < 25
      end

      inst = T.new("Whatever")

      nval.should_receive(:errors_for).with(inst.length).and_return(["error"])

      inst.should_not be_valid
      inst.errors.should have_exactly(1).item
      inst.errors[0].should == "error"
    end

    it "should catch match errors" do
      sval = mock("match validator")
      sval.should_receive(:matches)

      DataMapper::Validations::StringValidator.should_receive(:new).and_return(sval)

      class R < DataMapper::Types::String
        matches /aabb/
      end

      inst = R.new("Whatever")

      sval.should_receive(:errors_for).with(inst).and_return(["error"])

      inst.should_not be_valid
      inst.errors.should have_exactly(1).item
      inst.errors[0].should == "error"
    end

    it "should be valid" do
      nval = mock("length validator")
      nval.should_receive(:<)

      DataMapper::Validations::NumberValidator.should_receive(:new).and_return(nval)

      sval = mock("match validator")
      sval.should_receive(:matches)

      DataMapper::Validations::StringValidator.should_receive(:new).and_return(sval)

      class Q < DataMapper::Types::String
        length < 25
        matches /aabb/
      end

      inst = Q.new("Whatever")

      nval.should_receive(:errors_for).with(inst.length).and_return([])
      sval.should_receive(:errors_for).with(inst).and_return([])

      inst.should be_valid
      inst.errors.should be_empty
    end
  end
end
