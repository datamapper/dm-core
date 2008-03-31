require File.join(File.dirname(__FILE__), '..', 'spec_helper')
require __DIR__.parent.parent + 'lib/data_mapper/associations/child_to_parent_association.rb'

describe DataMapper::Associations::ChildToParentAssociation do
  before do
    @child = mock("child")
    @parent = mock("parent")
    @relationship = mock("relationship")
    @association = DataMapper::Associations::ChildToParentAssociation.new(@relationship, @child, nil)
  end

  describe "when the parent exists" do
    it "should attach the parent to the child" do
      @relationship.should_receive(:attach_parent).with(@child, @parent)
      @parent.should_receive(:new_record?).and_return(false)

      @association.parent = @parent

      @association.instance_variable_get("@parent").should == @parent
    end
  end
end


