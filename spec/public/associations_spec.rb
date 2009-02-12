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

  it { Car.should respond_to(:has) }

  describe '#has' do
    describe '1' do
      before :all do
        Car.has(1, :engine)

        @car = Car.new
      end

      it 'should create the accessor' do
        @car.should respond_to(:engine)
      end

      it 'should create the mutator' do
        @car.should respond_to(:engine=)
      end
    end

    describe 'n..n' do
      before :all do
        Car.has(1..4, :doors)

        @car = Car.new
      end

      it 'should create the accessor' do
        @car.should respond_to(:doors)
      end

      it 'should create the mutator' do
        @car.should respond_to(:doors=)
      end
    end

    describe 'n..n through' do
      before :all do
        Door.has(1, :window)
        Car.has(1..4, :doors)
        Car.has(1..4, :windows, :through => :doors)

        @car = Car.new
      end

      it 'should create the accessor' do
        @car.should respond_to(:windows)
      end

      it 'should create the mutator' do
        @car.should respond_to(:windows=)
      end
    end

    describe 'n' do
      before :all do
        Car.has(n, :doors)

        @car = Car.new
      end

      it 'should create the accessor' do
        @car.should respond_to(:doors)
      end

      it 'should create the mutator' do
        @car.should respond_to(:doors=)
      end
    end

    describe 'n through' do
      before :all do
        Door.has(1, :window)
        Car.has(n, :doors)
        Car.has(n, :windows, :through => :doors)

        @car = Car.new
      end

      it 'should create the accessor' do
        @car.should respond_to(:windows)
      end

      it 'should create the mutator' do
        @car.should respond_to(:windows=)
      end
    end

    it 'should raise an exception if the cardinality is not understood' do
      lambda { Car.has(n..n, :doors) }.should raise_error(ArgumentError)
    end

    it 'should raise an exception if the minimum constraint is larger than the maximum' do
      lambda { Car.has(2..1, :doors) }.should raise_error(ArgumentError)
    end
  end

  it { Engine.should respond_to(:belongs_to) }

  describe '#belongs_to' do
    before :all do
      Engine.belongs_to(:car)
      Car.has(n, :engines)

      @engine = Engine.new
    end

    it 'should create the accessor' do
      @engine.should respond_to(:car)
    end

    it 'should create the mutator' do
      @engine.should respond_to(:car=)
    end

    it 'should create the child key accessor' do
      @engine.should respond_to(:car_id)
    end

    it 'should create the child key mutator' do
      @engine.should respond_to(:car_id=)
    end

    # TODO: move the "querying" specs to the ManyToOne specs
    supported_by :all do
      describe 'querying for a parent resource' do
        before :all do
          @car = Car.create
          @engine = Engine.create(:car => @car)
          @resource = @engine.car(:id => @car.id)
        end

        it 'should return a Resource' do
          @resource.should be_kind_of(DataMapper::Resource)
        end

        it 'should return expected Resource' do
          @resource.should eql(@car)
        end
      end

      describe 'querying for a parent resource that does not exist' do
        before :all do
          @car = Car.create
          @engine = Engine.create(:car => @car)
          @resource = @engine.car(:id.not => @car.id)
        end

        it 'should return nil' do
          @resource.should be_nil
        end
      end

      describe 'changing the parent resource' do
        before :all do
          @car = Car.create
          @engine = Engine.new
          @engine.car = @car
        end

        it 'should set the associated foreign key' do
          @engine.car_id.should == @car.id
        end

        it 'should add the engine object to the car' do
          pending 'Changing a belongs_to parent should add the object to the correct association' do
            @car.engines.should include(@engine)
          end
        end
      end

      describe 'changing the parent foreign key' do
        before :all do
          @car = Car.create

          @engine = Engine.new
          @engine.car_id = @car.id
        end

        it 'should set the associated resource' do
          @engine.car.should eql(@car)
        end
      end

      describe 'changing an existing resource through the relation' do
        before :all do
          @car1 = Car.create
          @car2 = Car.create
          @engine = Engine.create(:car => @car1)
          @engine.car = @car2
        end

        it 'should also change the foreign key' do
          @engine.car_id.should == @car2.id
        end

        it 'should add the engine to the car' do
          pending 'Changing a belongs_to parent should add the object to the correct association' do
            @car2.engines.should include(@engine)
          end
        end
      end

      describe 'changing an existing resource through the relation' do
        before :all do
          @car1 = Car.create
          @car2 = Car.create
          @engine = Engine.create(:car => @car1)
          @engine.car_id = @car2.id
        end

        it 'should also change the foreign key' do
          pending 'a change to the foreign key should also change the related object' do
            @engine.car.should eql(@car2)
          end
        end

        it 'should add the engine to the car' do
          pending 'a change to the foreign key should also change the related object' do
            @car2.engines.should include(@engine)
          end
        end
      end
    end
  end
end
