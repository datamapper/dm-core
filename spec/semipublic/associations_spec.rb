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

    class Door
      include DataMapper::Resource
      property :id, Serial
    end

    class Window
      include DataMapper::Resource
      property :id, Serial
    end
  end

  describe "#has" do

    def n
      Car.n
    end

    describe "1" do
      before do
        @relationship = Car.has(1, :engine)
      end

      it "should return a DataMapper::Associations::Relationship" do
        @relationship.should be_a_kind_of(DataMapper::Associations::Relationship)
      end

      it "should return a relationship with the child model" do
        @relationship.child_model.should == Engine
      end
    end

    describe "n..n" do
      before do
        @relationship = Car.has(1..4, :doors)
      end

      it "should create a new relationship" do
        @relationship.should be_a_kind_of(DataMapper::Associations::Relationship)
      end

      it "should be a relationship with the child model" do
        @relationship.child_model.should == Door
      end

      describe "through" do
        before do
          pending do
            @relationship = Car.has(1..4, :windows, :through => :doors)
          end
        end

        it "should return a new relationship" do
          @relationship.should be_a_kind_of(DataMapper::Associations::Relationship)
        end
      end
    end

    describe "n" do
      before do
        @relationship = Car.has(n, :doors)
      end

      it "should be a relationship with the child model" do
        @relationship.child_model.should == Door
      end

      describe "through" do
        before do
          pending do
            @relationship = Car.has(n, :windows, :through => :doors)
          end
        end

        it "should return a new relationship" do
          @relationship.should be_a_kind_of(DataMapper::Associations::Relationship)
        end
      end
    end
  end

  describe "#belongs_to" do
    before do
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
