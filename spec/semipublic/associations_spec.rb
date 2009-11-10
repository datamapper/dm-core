require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

describe DataMapper::Associations do
  before :all do
    class ::Car
      include DataMapper::Resource

      property :id, Serial
    end

    class ::Engine
      include DataMapper::Resource

      property :id, Serial
    end

    class ::Door
      include DataMapper::Resource

      property :id, Serial
    end

    class ::Window
      include DataMapper::Resource

      property :id, Serial
    end
  end

  def n
    1.0/0
  end

  describe '#has' do
    describe '1' do
      before :all do
        @relationship = Car.has(1, :engine)
      end

      it 'should return a Relationship' do
        @relationship.should be_a_kind_of(DataMapper::Associations::OneToOne::Relationship)
      end

      it 'should return a Relationship with the child model' do
        @relationship.child_model.should == Engine
      end

      it 'should return a Relationship with a min of 1' do
        @relationship.min.should == 1
      end

      it 'should return a Relationship with a max of 1' do
        @relationship.max.should == 1
      end
    end

    describe 'n..n' do
      before :all do
        @relationship = Car.has(1..4, :doors)
      end

      it 'should return a Relationship' do
        @relationship.should be_a_kind_of(DataMapper::Associations::OneToMany::Relationship)
      end

      it 'should return a Relationship with the child model' do
        @relationship.child_model.should == Door
      end

      it 'should return a Relationship with a min of 1' do
        @relationship.min.should == 1
      end

      it 'should return a Relationship with a max of 4' do
        @relationship.max.should == 4
      end
    end

    describe 'n..n through' do
      before :all do
        Door.has(1, :window)
        Car.has(1..4, :doors)

        @relationship = Car.has(1..4, :windows, :through => :doors)
      end

      it 'should return a Relationship' do
        @relationship.should be_a_kind_of(DataMapper::Associations::ManyToMany::Relationship)
      end

      it 'should return a Relationship with the child model' do
        @relationship.child_model.should == Window
      end

      it 'should return a Relationship with a min of 1' do
        @relationship.min.should == 1
      end

      it 'should return a Relationship with a max of 4' do
        @relationship.max.should == 4
      end
    end

    describe 'n' do
      before :all do
        @relationship = Car.has(n, :doors)
      end

      it 'should return a Relationship' do
        @relationship.should be_a_kind_of(DataMapper::Associations::OneToMany::Relationship)
      end

      it 'should return a Relationship with the child model' do
        @relationship.child_model.should == Door
      end

      it 'should return a Relationship with a min of 0' do
        @relationship.min.should == 0
      end

      it 'should return a Relationship with a max of n' do
        @relationship.max.should == n
      end
    end

    describe 'n through' do
      before :all do
        Door.has(1, :windows)
        Car.has(1..4, :doors)

        @relationship = Car.has(n, :windows, :through => :doors)
      end

      it 'should return a Relationship' do
        @relationship.should be_a_kind_of(DataMapper::Associations::ManyToMany::Relationship)
      end

      it 'should return a Relationship with the child model' do
        @relationship.child_model.should == Window
      end

      it 'should return a Relationship with a min of 0' do
        @relationship.min.should == 0
      end

      it 'should return a Relationship with a max of n' do
        @relationship.max.should == n
      end
    end
  end

  describe '#belongs_to' do
    before :all do
      @relationship = Engine.belongs_to(:car)
    end

    it 'should return a Relationship' do
      @relationship.should be_a_kind_of(DataMapper::Associations::ManyToOne::Relationship)
    end

    it 'should return a Relationship with the parent model' do
      @relationship.parent_model.should == Car
    end

    it 'should return a Relationship with a min of 1' do
      @relationship.min.should == 1
    end

    it 'should return a Relationship with a max of 1' do
      @relationship.max.should == 1
    end

    it 'should return a Relationship that is required' do
      @relationship.required?.should be_true
    end
  end
end
