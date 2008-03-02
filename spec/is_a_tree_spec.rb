require File.dirname(__FILE__) + "/spec_helper"

class DataMapper::MockBase
	include DataMapper::Is::Tree
end

class DefaultTree < DataMapper::MockBase
end

describe "DataMapper::Is::Tree receiving various is_a_tree configurations" do
	setup do
		DefaultTree.stub!(:has_many)
		DefaultTree.stub!(:belongs_to)
	end

	it "should setup a belongs_to relationship with the parent with the default configurations" do
		DefaultTree.should_receive(:belongs_to).with(:parent, :foreign_key => "parent_id", :counter_cache => nil,
																								 :class_name => "DefaultTree")
		DefaultTree.send(:is_a_tree)
	end

	it "should setup a has_many relationship with the children with default configurations" do
		DefaultTree.should_receive(:has_many).with(:children, :foreign_key => "parent_id", :order => nil,
																							 :class_name => "DefaultTree")
		DefaultTree.send(:is_a_tree)
	end

	it "should setup a belongs_to relationship with the correct foreign key" do
		DefaultTree.should_receive(:belongs_to).with(:parent, :foreign_key => "something_id", :counter_cache => nil,
																								 :class_name => "DefaultTree")
		DefaultTree.send(:is_a_tree, :foreign_key => "something_id")
	end

	it "should setup a has_many relationship with the children with the correct foreign key" do
		DefaultTree.should_receive(:has_many).with(:children, :foreign_key => "something_id", :order => nil,
																							 :class_name => "DefaultTree")
		DefaultTree.send(:is_a_tree, :foreign_key => "something_id")
	end

	it "should setup a has_many relationship with the children with the correct order" do
		DefaultTree.should_receive(:has_many).with(:children, :foreign_key => "parent_id", :order => 'position',
																							 :class_name => "DefaultTree")
		DefaultTree.send(:is_a_tree, :order => 'position')
	end
end

describe "Default DataMapper::Is::Tree class methods" do
	setup do
		DefaultTree.stub!(:has_many)
		DefaultTree.stub!(:belongs_to)
		DefaultTree.send(:can_has_tree)
		DefaultTree.stub!(:all).and_return([])
		DefaultTree.stub!(:first).and_return(nil)
	end

	it "should return an empty array for .roots" do
		DefaultTree.roots.should == []
	end

	it "should find with the correct options on .roots" do
		DefaultTree.should_receive(:all).with(:parent_id => nil, :order => nil)
		DefaultTree.roots
	end

	it "should return nil for .first_root" do
		DefaultTree.root.should be_nil
	end

	it "should find with the correct options on .first_root" do
		DefaultTree.should_receive(:first).with(:parent_id => nil, :order => nil)
		DefaultTree.first_root
	end
end

describe "Configured DataMapper::Is::Tree class methods" do
	setup do
		DefaultTree.stub!(:has_many)
		DefaultTree.stub!(:belongs_to)
		DefaultTree.send(:can_has_tree, :foreign_key => 'mew_id', :order => 'mew')
		DefaultTree.stub!(:all).and_return([])
		DefaultTree.stub!(:first).and_return(nil)
	end

	it "should return an empty array for .roots" do
		DefaultTree.roots.should == []
	end

	it "should find with the correct options on .roots" do
		DefaultTree.should_receive(:all).with(:mew_id => nil, :order => 'mew')
		DefaultTree.roots
	end

	it "should return nil for .first_root" do
		DefaultTree.root.should be_nil
	end

	it "should find with the correct options on .first_root" do
		DefaultTree.should_receive(:first).with(:mew_id => nil, :order => 'mew')
		DefaultTree.first_root
	end
end

describe "Default DataMapper::Is::Tree instance methods" do
	setup do
		DefaultTree.stub!(:has_many)
		DefaultTree.stub!(:belongs_to)
		DefaultTree.send(:is_a_tree)
		@root = DefaultTree.new
		@child = DefaultTree.new
		@grandchild1 = DefaultTree.new
		@grandchild2 = DefaultTree.new

		# Mocking the belongs_to & has_many relationships (part of the not-needing-a-db-to-test plan)
		@root.stub!(:parent).and_return nil
		@child.stub!(:parent).and_return @root
		@grandchild1.stub!(:parent).and_return(@child)
		@grandchild2.stub!(:parent).and_return(@child)
		@child.stub!(:children).and_return([@grandchild1, @grandchild2])
		@root.stub!(:children).and_return([@child])
		@grandchild1.stub!(:children).and_return []
		@grandchild2.stub!(:children).and_return []
	end

	it "should return an array of parents, furthest parent first, for #ancestors" do
		@grandchild1.ancestors.should == [@root, @child]
	end

	it "should return an array of siblings for #siblings" do
		@grandchild1.siblings.should == [@grandchild2]
	end

	it "should return all children of the node's parent for #generation" do
		@grandchild1.generation.should == [@grandchild1, @grandchild2]
	end

	it "should return roots on #generation when there is no parent" do
		DefaultTree.should_receive(:roots).and_return [@root]
		@root.generation.should == [@root]
	end

	it "should return the top-most parent on #root" do
		@grandchild1.root.should == @root
	end

	it "should return self on #root if self has no parent" do
		@root.root.should == @root
	end

end
