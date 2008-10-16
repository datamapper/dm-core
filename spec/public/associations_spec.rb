require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

describe DataMapper::Associations do
  before do
    class Car
      include DataMapper::Resource
      property :id, Serial
    end
    
    class Engine
      include DataMapper::Resource
      property :id, Serial
    end
  end
  
  it "should respond to #has" do
    Car.should respond_to(:has)
  end
  
  describe "#has" do
    before(:each) do
      @relationship = Car.has(1, :engine)
    end
    
    it "should return a DataMapper::Associations::Relationship" do
      @relationship.should be_a_kind_of(DataMapper::Associations::Relationship)
    end
    
    it "should raise an ArgumentError if the cardinality is not understood" do
      lambda { Car.has(n..n, :doors) }.should raise_error(ArgumentError)
    end
    
    it "should raise an ArgumentError if the name argument has more than one key" do
      lambda { Car.has(n, :doors => :windows, :wipers => :windows) }.should raise_error(ArgumentError)
    end
    
    it "should raise an ArgumentError if the minimum constraint is larger than the maximum" do
      lambda { Car.has(3..1, :doors) }.should raise_error(ArgumentError)
    end
    
    describe "1" do
      it "should return a relationship with the child model" do
        @relationship.child_model.should == Engine
      end
    end
      
    describe "n" do
      before(:each) do
        class Door
          include DataMapper::Resource
          property :id, Serial
        end
        
        @relationship = Car.has(n, :doors)
      end
      
      it "should return a relationship with the child model" do
        @relationship.child_model.should == Door
      end
    
      describe "through" do
        before(:each) do
          class Car
            include DataMapper::Resource
            property :id, Serial
          
            has n, :doors
          end
        
          class Door
            include DataMapper::Resource
            property :id, Serial
          end
        
          class Window
            include DataMapper::Resource
            property :id, Serial
          end
        
          @relationship = Car.has(n, :windows, :through => :doors)
        end
      
        it "should return the new relationship" do
          @relationship.should be_a_kind_of(DataMapper::Associations::Relationship)
        end
      end
    end
  end
  
  it "should respond to #belongs_to" do
    Engine.should respond_to(:belongs_to)
  end
  
  describe "#belongs_to" do
    before(:each) do
      @relationship = Engine.belongs_to(:car)
    end
    
    it "should return a new relationship" do
      @relationship.should be_a_kind_of(DataMapper::Associations::Relationship)
    end
    
    it "should return the relationship with the parent model" do
      @relationship.parent_model.should == Car
    end
  end
end