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

      property :user_id, Fixnum, :key => true
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
  describe "when adding a resource" do
    before do
      @parent = mock("parent")
      @resource = mock("resource", :null_object => true)
      @collection = mock("collection")
      @repository = mock("repository", :save => nil)
      @relationship = mock("relationship")
      @association = DataMapper::Associations::OneToMany::Proxy.new(@relationship, @parent, @collection)
    end

    describe "with a persisted parent" do
      it "should save the resource" do
        @parent.should_receive(:new_record?).with(no_args).once.and_return(false)
        @relationship.should_receive(:attach_parent).with(@resource, @parent)
        @relationship.should_receive(:repository_name).with(no_args).once.and_return(:a_symbol)
        @collection.should_receive(:<<).with(@resource).once.and_return(@collection)

        @association << @resource

        @association.instance_variable_get("@dirty_children").should be_empty
      end
    end

    describe "with a non-persisted parent" do
      it "should not save the resource" do
        @parent.should_receive(:new_record?).and_return(true)
        @association.should_not_receive(:save_resource)
        @collection.should_receive(:<<).with(@resource).once.and_return(@collection)

        @association << @resource

        @association.instance_variable_get("@dirty_children").should_not be_empty
      end

      it "should save the resource after the parent is saved" do

      end

      it "should add the parent's keys to the resource after the parent is saved"
    end
  end

  describe "when deleting a resource" do
    it "should delete the resource from the database"

    it "should delete the resource from the association"

    it "should erase the ex-parent's keys from the resource"
  end

  describe "when deleting the parent" do

  end

  describe "with an unsaved parent" do
    describe "when deleting a resource from an unsaved parent" do
      it "should remove the resource from the association" do

      end
    end
  end
end

describe "when changing a resource's parent" do

end
