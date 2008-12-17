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

  supported_by :all do
    it { Car.should respond_to(:has) }

    describe '#has' do
      def n
        Car.n
      end

      it 'should raise an ArgumentError if the cardinality is not understood' do
        lambda { Car.has(n..n, :doors) }.should raise_error(ArgumentError)
      end

      it 'should raise an ArgumentError if the minimum constraint is larger than the maximum' do
        lambda { Car.has(3..1, :doors) }.should raise_error(ArgumentError)
      end

      describe '1' do
        before do
          @relationship = Car.has(1, :engine)
          @car = Car.new
        end

        it 'should add the accessor' do
          @car.should respond_to(:engine)
        end

        it 'should add the mutator' do
          @car.should respond_to(:engine=)
        end
      end

      describe 'n..n' do
        before do
          @relationship = Car.has(1..4, :doors)
          @car = Car.new
        end

        it 'should add the accessor' do
          @car.should respond_to(:doors)
        end

        it 'should add the mutator' do
          @car.should respond_to(:doors=)
        end
      end

      describe 'n..n through' do
        before do
          pending do
            @relationship = Car.has(1..4, :windows, :through => :doors)
            @car = Car.new
          end
        end

        it 'should add the accessor' do
          @car.should respond_to(:windows)
        end

        it 'should add the mutator' do
          @car.should respond_to(:windows=)
        end
      end

      describe 'n' do
        before do
          @relationship = Car.has(n, :doors)
          @car          = Car.new
        end

        it 'should add the accessor' do
          @car.should respond_to(:doors)
        end

        describe 'and through option' do
          before do
            pending do
              @relationship = Car.has(n, :windows, :through => :doors)
              @car          = Car.new
            end
          end

          it 'should add the windows getter' do
            @car.should respond_to(:windows)
          end
        end
      end
    end

    it { Engine.should respond_to(:belongs_to) }

    describe '#belongs_to' do
      before do
        @relationship       = Engine.belongs_to(:car)
        @other_relationship = Car.has(Car.n, :engines)
        @engine             = Engine.new

        unless @adapter.kind_of?(DataMapper::Adapters::InMemoryAdapter)
          DataMapper.auto_migrate!
        end
      end

      it 'should add the accessor' do
        @engine.should respond_to(:car)
      end

      it 'should add the mutator' do
        @engine.should respond_to(:car=)
      end

      it 'should add the child key accessor' do
        @engine.should respond_to(:car_id)
      end

      it 'should add the child key mutator' do
        @engine.should respond_to(:car_id=)
      end

      describe 'querying for a parent resource' do
        before do
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
        before do
          @car = Car.create
          @engine = Engine.create(:car => @car)
          @resource = @engine.car(:id.not => @car.id)
        end

        it 'should return nil' do
          @resource.should be_nil
        end
      end

      describe 'changing the parent resource' do
        before do
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
        before do
          @car = Car.create

          @engine = Engine.new
          @engine.car_id = @car.id
        end

        it 'should set the associated resource' do
          @engine.car.should eql(@car)
        end
      end

      describe 'changing an existing resource through the relation' do
        before do
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
        before do
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
