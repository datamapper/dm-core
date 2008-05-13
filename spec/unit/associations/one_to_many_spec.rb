require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'spec_helper'))

describe DataMapper::Associations::OneToMany do
  before do
    @class = Class.new do
      def self.name
        'User'
      end

      include DataMapper::Resource

      class << self
        public :one_to_many
      end

      property :user_id, Integer, :key => true
    end
  end

  describe '#one_to_many' do
    it 'should provide #one_to_many' do
      @class.should respond_to(:one_to_many)
    end

    it 'should return a Relationship' do
      @class.one_to_many(:orders).should be_kind_of(DataMapper::Associations::Relationship)
    end

    describe 'relationship' do
      before do
        @relationship = mock('relationship')
        DataMapper::Associations::Relationship.stub!(:new).and_return(@relationship)
      end

      it 'should receive the name' do
        DataMapper::Associations::Relationship.should_receive(:new) do |name,_,_,_,_|
          name.should == :user
        end
        @class.one_to_many(:orders)
      end

      it 'should receive the repository name' do
        DataMapper::Associations::Relationship.should_receive(:new) do |_,repository_name,_,_,_|
          repository_name.should == :one_to_many_spec
        end
        repository(:one_to_many_spec) do
          @class.one_to_many(:orders)
        end
      end

      it 'should recieve the child model name when passed in as class_name' do
        DataMapper::Associations::Relationship.should_receive(:new) do |_,_,child_model_name,_,_|
          child_model_name.should == 'Company::Order'
        end
        @class.one_to_many(:orders, :class_name => 'Company::Order')
      end

      it 'should recieve the child model name when class_name not passed in' do
        DataMapper::Associations::Relationship.should_receive(:new) do |_,_,child_model_name,_,_|
          child_model_name.should == 'Order'
        end
        @class.one_to_many(:orders)
      end

      it 'should recieve the parent model name' do
        DataMapper::Associations::Relationship.should_receive(:new) do |_,_,_,parent_model_name,_|
          parent_model_name.should == 'User'
        end
        @class.one_to_many(:orders)
      end

      it 'should recieve the parent model name' do
        options = { :min => 0, :max => 100 }
        DataMapper::Associations::Relationship.should_receive(:new) do |_,_,_,parent_model_name,_|
          options.object_id.should == options.object_id
        end
        @class.one_to_many(:orders, options)
      end
    end

    it 'should add an accessor for the proxy' do
      @class.new.should_not respond_to(:orders)
      @class.one_to_many(:orders)
      @class.new.should respond_to(:orders)
    end

    describe 'proxy accessor' do
      before :all do
        class User
          include DataMapper::Resource
          class << self
            public :one_to_many
          end
        end

        class Order
          include DataMapper::Resource
        end
      end

      it 'should return a OneToMany::Proxy' do
        @class.one_to_many(:orders)
        @class.new.orders.should be_kind_of(DataMapper::Associations::OneToMany::Proxy)
      end
    end
  end

  it "should work with classes inside modules"
end

describe DataMapper::Associations::OneToMany::Proxy do
  before do
    @parent = mock("parent", :new_record? => true)
    @resource = mock("resource", :null_object => true)
    @collection = []
    @repository = mock("repository", :save => nil)
    @relationship = mock("relationship", :get_children => @collection, :repository_name => :a_symbol)
    @association = DataMapper::Associations::OneToMany::Proxy.new(@relationship, @parent)
  end

  describe "when adding a resource" do
    describe "with a persisted parent" do
      it "should save the resource" do
        @parent.should_receive(:new_record?).with(no_args).once.and_return(false)
        @relationship.should_receive(:attach_parent).with(@resource, @parent).once
        @collection.should_receive(:<<).with(@resource).once.and_return(@collection)

        @association << @resource
      end
    end

    describe "with a non-persisted parent" do
      it "should not save the resource" do
        @parent.should_receive(:new_record?).and_return(true)
        @association.should_not_receive(:save_resource)
        @collection.should_receive(:<<).with(@resource).once.and_return(@collection)

        @association << @resource
      end

      it "should save the resource after the parent is saved"

      it "should add the parent's keys to the resource after the parent is saved"
    end
  end

  describe "when deleting a resource" do
    before do
      @collection.stub!(:delete).and_return(@resource)
      @relationship.stub!(:attach_parent).once
    end

    it "should delete the resource from the database" do
      @resource.should_receive(:save).with(no_args).once

      @association.delete(@resource)
    end

    it "should delete the resource from the association" do
      @collection.should_receive(:delete).with(@resource).once.and_return(@resource)

      @association.delete(@resource)
    end

    it "should erase the ex-parent's keys from the resource" do
      @relationship.should_receive(:attach_parent).with(@resource, nil).once

      @association.delete(@resource)
    end
  end

  describe "when deleting the parent" do
    it "should delete all the children without calling destroy if relationship :dependent is :delete_all"

    it "should destroy all the children if relationship :dependent is :destroy"

    it "should set the children's parent key to nil if relationship :dependent is :nullify"

    it "should restrict the parent from being deleted if a child remains if relationship :dependent is restrict"

    it "should be restrict by default if relationship :dependent is not specified"
  end

  describe "when replacing the children" do
    before do
      @children = [
        mock("child 1"),
        mock("child 2"),
      ]
      @collection << @resource
      @relationship.stub!(:attach_parent)
    end

    it "should remove each resource" do
      @relationship.should_receive(:attach_parent).with(@resource, nil).once
      @resource.should_receive(:save).with(no_args).once

      @association.replace(@children)
    end

    it "should replace the children in the collection" do
      @children.should_not == @collection
      @association.entries.should == @collection

      @association.replace(@children)

      @children.should == @collection  # collection was modified
      @association.entries.should == @collection
    end
  end

  describe "with an unsaved parent" do
    describe "when deleting a resource from an unsaved parent" do
      it "should remove the resource from the association"
    end
  end
end
