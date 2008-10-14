require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

describe DataMapper::Associations do
  before do
    class Car
      include DataMapper::Resource
      property :id, Serial

      has 1, :engine
    end

    class Engine
      include DataMapper::Resource
      property :id, Serial

      belongs_to :car
    end
    
    @relationship = Car.relationships[:engine]
  end
  
  it "should respond to #has" do
    Car.should respond_to(:has)
  end
  
  describe "#has" do
    it "should return a DataMapper::Associations::Relationship" do
      @relationship.should be_an_instance_of(DataMapper::Associations::Relationship)
    end
      
    describe "1" do
      it "should be a OneToOne relationship"
    end
      
    describe "n" do
      before(:each) do
        class Car
          include DataMapper::Resource
          property :id, Serial

          has n, :doors
        end
        
        class Door
          include DataMapper::Resource
          property :id, Serial

          belongs_to :car
        end
        
        @car = Car.new
        @relationship = Car.relationships[:doors]
      end
      
      it "return a OneToMany relationship"
    end
  end
  
  it "should respond to #belongs_to" do
    Engine.should respond_to(:belongs_to)
  end
  
  describe "#belongs_to" do
  end
end