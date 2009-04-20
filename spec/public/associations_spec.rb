require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

share_examples_for 'it creates a one accessor' do
  describe 'accessor' do
    describe 'when there is no associated resource' do
      describe 'without a query' do
        before :all do
          @return = @car.send(@name)
        end

        it 'should return nil' do
          @return.should be_nil
        end
      end

      describe 'with a query' do
        before :all do
          @car.save

          @return = @car.send(@name, :id => 1)
        end

        it 'should return nil' do
          @return.should be_nil
        end
      end
    end

    describe 'when there is an associated resource' do
      before :all do
        @expected = @model.new
        @car.send("#{@name}=", @expected)

        @return = @car.send(@name)
      end

      describe 'without a query' do
        it 'should return a Resource' do
          @return.should be_kind_of(DataMapper::Resource)
        end

        it 'should return the expected Resource' do
          @return.should equal(@expected)
        end
      end

      describe 'with a query' do
        before :all do
          @car.save

          @return = @car.send(@name, :id => @expected.id)
        end

        it 'should return a Resource' do
          @return.should be_kind_of(DataMapper::Resource)
        end

        it 'should return the expected Resource' do
          @return.should == @expected
        end
      end
    end
  end
end

share_examples_for 'it creates a one mutator' do
  describe 'mutator' do
    describe 'when setting an associated resource' do
      before do
        @expected = @model.new

        @return = @car.send("#{@name}=", @expected)
      end

      it 'should return the expected Resource' do
        @return.should equal(@expected)
      end

      it 'should set the Resource' do
        @car.send(@name).should equal(@expected)
      end

      it 'should relate associated Resource' do
        pending do
          @expected.car.should == @car
        end
      end

      it 'should persist the Resource' do
        @car.save
        @car.reload.send(@name).should == @expected
      end

      it 'should persist the associated Resource' do
        pending_if 'TODO', Car.relationships[@name].kind_of?(DataMapper::Associations::ManyToOne::Relationship) do
          @car.save
          @expected.should be_saved
          @expected.reload.car.should == @car
        end
      end
    end

    describe 'when setting a nil resource' do
      before :all do
        @car.send("#{@name}=", @model.new)

        @return = @car.send("#{@name}=", nil)
      end

      it 'should return nil' do
        @return.should be_nil
      end

      it 'should set nil' do
        @car.send(@name).should be_nil
      end

      it 'should persist as nil' do
        @car.save
        @car.reload.send(@name).should be_nil
      end
    end

    describe 'when changing an associated resource' do
      before :all do
        @car.send("#{@name}=", @model.new)
        @car.save
        @expected = @model.new

        @return = @car.send("#{@name}=", @expected)
      end

      it 'should return the expected Resource' do
        @return.should equal(@expected)
      end

      it 'should set the Resource' do
        @car.send(@name).should equal(@expected)
      end

      it 'should relate associated Resource' do
        pending_if 'should create back-reference', Car.relationships[@name].kind_of?(DataMapper::Associations::ManyToOne::Relationship) do
          @expected.car.should == @car
        end
      end

      it 'should persist the Resource' do
        @car.save
        @car.reload.send(@name).should == @expected
      end

      it 'should persist the associated Resource' do
        pending_if 'TODO', Car.relationships[@name].kind_of?(DataMapper::Associations::ManyToOne::Relationship) do
          @car.save
          @expected.should be_saved
          @expected.reload.car.should == @car
        end
      end
    end
  end
end

share_examples_for 'it creates a many accessor' do
  describe 'when there is no child resource' do
    before :all do
      @return = @car.send(@name)
    end

    it 'should return a Collection' do
      @return.should be_kind_of(DataMapper::Collection)
    end

    it 'should return an empty Collection' do
      @return.should be_empty
    end
  end

  describe 'when there is a child resource' do
    before :all do
      @skip = Car.relationships[@name].kind_of?(DataMapper::Associations::ManyToMany::Relationship)

      @return = nil

      rescue_if 'TODO', @skip do
        @expected = @model.new
        @car.send("#{@name}=", [ @expected ])

        @return = @car.send(@name)
      end
    end

    it 'should return a Collection' do
      pending_if 'TODO', @skip do
        @return.should be_kind_of(DataMapper::Collection)
      end
    end

    it 'should return expected Resources' do
      pending_if 'TODO', @skip do
        @return.should == [ @expected ]
      end
    end
  end
end

share_examples_for 'it creates a many mutator' do
  # TODO: write this
end

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
        @model = Engine
        @name  = :engine

        Car.has(1, @name)
        Engine.belongs_to(:car)
      end

      supported_by :all do
        before :all do
          @car = Car.new
        end

        it { @car.should respond_to(@name) }

        it_should_behave_like 'it creates a one accessor'

        it { @car.should respond_to("#{@name}=") }

        it_should_behave_like 'it creates a one mutator'
      end
    end

    describe 'n..n' do
      before :all do
        @model = Door
        @name  = :doors

        Car.has(1..4, @name)
        Door.belongs_to(:car)
      end

      supported_by :all do
        before :all do
          @car = Car.new
        end

        it { @car.should respond_to(@name) }

        it_should_behave_like 'it creates a many accessor'

        it { @car.should respond_to("#{@name}=") }

        it_should_behave_like 'it creates a many mutator'
      end
    end

    describe 'n..n through' do
      before :all do
        @model = Window
        @name  = :windows

        Door.belongs_to(:car)
        Door.has(1, :window)
        Window.belongs_to(:door)
        Car.has(1..4, :doors)
        Car.has(1..4, :windows, :through => :doors)
      end

      supported_by :all do
        before :all do
          @car = Car.new
        end

        it { @car.should respond_to(@name) }

        it_should_behave_like 'it creates a many accessor'

        it { @car.should respond_to("#{@name}=") }

        it_should_behave_like 'it creates a many mutator'
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
      @model = Engine
      @name  = :engine

      Car.belongs_to(@name)
      Engine.has(1, :car)
    end

    supported_by :all do
      before :all do
        @car = Car.new
      end

      it { @car.should respond_to(@name) }

      it_should_behave_like 'it creates a one accessor'

      it { @car.should respond_to("#{@name}=") }

      it_should_behave_like 'it creates a one mutator'
    end

    # TODO: refactor these specs into above structure once they pass
    describe 'pending query specs' do
      before :all do
        Car.has(1, :engine)
        Engine.belongs_to(:car)
      end

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
              @car.engines.should be_include(@engine)
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
              @car2.engines.should be_include(@engine)
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
              @car2.engines.should be_include(@engine)
            end
          end
        end
      end
    end
  end
end
