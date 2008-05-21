require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'spec_helper'))

describe "DataMapper::Associations::ManyToOne" do

  it "should allow a declaration" do
    lambda do
      class Vehicle
        many_to_one :manufacturer
      end
    end.should_not raise_error
  end

  describe DataMapper::Associations::ManyToOne::Proxy do
    before do
      @child = mock("child")
      @parent = mock("parent")
      @relationship = mock("relationship")
      @association = DataMapper::Associations::ManyToOne::Proxy.new(@relationship, @child)
    end

    describe "when the parent exists" do
      it "should attach the parent to the child" do
        @parent.should_receive(:new_record?).and_return(false)
        @relationship.should_receive(:attach_parent).with(@child, @parent)

        @association.replace(@parent)
      end
    end
    describe "when the parent is nil" do
      it "should save without consequence" do
        @relationship.should_receive(:get_parent).with(@child)
        @association.save
      end
    end
  end
end
