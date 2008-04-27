require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'spec_helper'))

describe "DataMapper::Associations::OneToMany" do

  before do
    @class = Class.new do
      def self.name
        "Hannibal"
      end

      include DataMapper::Resource

      property :id, Fixnum

      send :one_to_many, :vehicles
    end

    @relationship = mock("relationship")
  end
    
  it "should install the association's methods" do
    victim = @class.new
      
    victim.should respond_to(:vehicles)
  end
  
  it "should work with classes inside modules"

  describe DataMapper::Associations::OneToMany::Proxy do
    describe "when loading" do
      def init
        DataMapper::Associations::OneToMany::Proxy.new(@relationship, nil) do |one, two|
          @tester.weee
        end 
      end

      before do
        @tester = mock("tester")
      end

      it "should not load on initialize" do
        @tester.should_not_receive(:weee)
        init
      end

      it "should load when accessed" do
        @relationship.should_receive(:repository_name).and_return(:a_symbol)
        @tester.should_receive(:weee).and_return([])
        a = init
        a.entries
      end
    end

    describe "when adding an element" do
      before do
        @parent = mock("parent")
        @element = mock("element", :null_object => true)
        @association = DataMapper::Associations::OneToMany::Proxy.new(@relationship, @parent) do
          []
        end 
      end

      describe "with a persisted parent" do
        it "should save the element" do
          @relationship.should_receive(:repository_name).and_return(:a_symbol)
          @parent.should_receive(:new_record?).and_return(false)
          @association.should_receive(:save_child).with(@element)

          @association << @element

          @association.instance_variable_get("@dirty_children").should be_empty
        end
      end

      describe "with a non-persisted parent" do
        it "should not save the element" do
          @relationship.should_receive(:repository_name).and_return(:a_symbol)
          @parent.should_receive(:new_record?).and_return(true)
          @association.should_not_receive(:save_child)

          @association << @element

          @association.instance_variable_get("@dirty_children").should_not be_empty
        end

        it "should save the element after the parent is saved" do

        end

        it "should add the parent's keys to the element after the parent is saved"
      end
    end

    describe "when deleting an element" do
      it "should delete the element from the database" do
      
      end

      it "should delete the element from the association"
    
      it "should erase the ex-parent's keys from the element"
    end

    describe "when deleting the parent" do
    
    end


    describe "with an unsaved parent" do
      describe "when deleting an element from an unsaved parent" do
        it "should remove the element from the association" do
      
        end    
      end
    end
  end
  
  describe "when changing an element's parent" do
    
  end
end
