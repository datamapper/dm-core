require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'spec_helper'))

share_examples_for 'it creates a one accessor' do
  describe 'accessor' do
    describe 'when there is no associated resource' do
      describe 'without a query' do
        before :all do
          @return = @car.__send__(@name)
        end

        it 'should return nil' do
          @return.should be_nil
        end
      end

      describe 'with a query' do
        before :all do
          @return = @car.__send__(@name, :id => 99)
        end

        it 'should return nil' do
          @return.should be_nil
        end
      end
    end

    describe 'when there is an associated resource' do
      before :all do
        @expected = @model.new
        @car.__send__("#{@name}=", @expected)
      end

      describe 'without a query' do
        before :all do
          @return = @car.__send__(@name)
        end

        it 'should return a Resource' do
          @return.should be_kind_of(DataMapper::Resource)
        end

        it 'should return the expected Resource' do
          @return.should equal(@expected)
        end
      end

      describe 'with a query' do
        before :all do
          @car.save  # save @car and @expected to set @expected.id

          @expected.id.should_not be_nil

          @return = @car.__send__(@name, :id => @expected.id)
        end

        it 'should return a Resource' do
          @return.should be_kind_of(DataMapper::Resource)
        end

        it 'should return the expected Resource' do
          @return.should == @expected
        end
      end
    end

    describe 'when the target model is scoped' do
      before :all do
        @resource = @model.new
        @car.__send__("#{@name}=", @resource)
        @car.save

        # set the model scope to not match the expected resource
        @model.default_scope.update(:id.not => @resource.id)

        @return = @car.model.get(*@car.key).__send__(@name)
      end

      it 'should return nil' do
        @return.should be_nil
      end
    end
  end
end

share_examples_for 'it creates a one mutator' do
  describe 'mutator' do
    describe 'when setting a Resource' do
      before :all do
        @expected = @model.new

        @return = @car.__send__("#{@name}=", @expected)
      end

      it 'should return the expected Resource' do
        @return.should equal(@expected)
      end

      it 'should set the Resource' do
        @car.__send__(@name).should equal(@expected)
      end

      it 'should relate associated Resource' do
        relationship       = Car.relationships[@name]
        many_to_one        = relationship.kind_of?(DataMapper::Associations::ManyToOne::Relationship)
        one_to_one_through = relationship.kind_of?(DataMapper::Associations::OneToOne::Relationship) && relationship.respond_to?(:through)

        pending_if many_to_one || one_to_one_through do
          @expected.car.should == @car
        end
      end

      it 'should persist the Resource' do
        @car.save.should be_true
        @car.model.get(*@car.key).__send__(@name).should == @expected
      end

      it 'should persist the associated Resource' do
        @car.save.should be_true
        @expected.should be_saved
        @expected.model.get(*@expected.key).car.should == @car
      end
    end

    describe 'when setting a Hash' do
      before :all do
        @car.__send__("#{@name}=", @model.new)

        attributes = { :id => 10 }
        @expected  = @model.new(attributes)

        @return = @car.__send__("#{@name}=", attributes)
      end

      it 'should return the expected Resource' do
        @return.should == @expected
      end

      it 'should set the Resource' do
        @car.__send__(@name).should equal(@return)
      end

      it 'should relate associated Resource' do
        relationship       = Car.relationships[@name]
        many_to_one        = relationship.kind_of?(DataMapper::Associations::ManyToOne::Relationship)
        one_to_one_through = relationship.kind_of?(DataMapper::Associations::OneToOne::Relationship) && relationship.respond_to?(:through)

        pending_if many_to_one || one_to_one_through do
          @return.car.should == @car
        end
      end

      it 'should persist the Resource' do
        @car.save.should be_true
        @car.model.get(*@car.key).__send__(@name).should == @return
      end

      it 'should persist the associated Resource' do
        @car.save.should be_true
        @return.should be_saved
        @return.model.get(*@return.key).car.should == @car
      end
    end

    describe 'when setting nil' do
      before :all do
        @car.__send__("#{@name}=", @model.new)

        @return = @car.__send__("#{@name}=", nil)
      end

      it 'should return nil' do
        @return.should be_nil
      end

      it 'should set nil' do
        @car.__send__(@name).should be_nil
      end

      it 'should persist as nil' do
        @car.save.should be_true
        @car.model.get(*@car.key).__send__(@name).should be_nil
      end
    end

    describe 'when changing the Resource' do
      before :all do
        @car.__send__("#{@name}=", @model.new)
        @expected = @model.new

        @return = @car.__send__("#{@name}=", @expected)
      end

      it 'should return the expected Resource' do
        @return.should equal(@expected)
      end

      it 'should set the Resource' do
        @car.__send__(@name).should equal(@expected)
      end

      it 'should relate associated Resource' do
        relationship       = Car.relationships[@name]
        many_to_one        = relationship.kind_of?(DataMapper::Associations::ManyToOne::Relationship)
        one_to_one_through = relationship.kind_of?(DataMapper::Associations::OneToOne::Relationship) && relationship.respond_to?(:through)

        pending_if 'should create back-reference', many_to_one || one_to_one_through do
          @expected.car.should == @car
        end
      end

      it 'should persist the Resource' do
        @car.save.should be_true
        @car.model.get(*@car.key).__send__(@name).should == @expected
      end

      it 'should persist the associated Resource' do
        @car.save.should be_true
        @expected.should be_saved
        @expected.model.get(*@expected.key).car.should == @car
      end
    end
  end
end

share_examples_for 'it creates a many accessor' do
  describe 'accessor' do
    describe 'when there is no child resource and the source is saved' do
      before :all do
        @car.save.should be_true
        @return = @car.__send__(@name)
      end

      it 'should return a Collection' do
        @return.should be_kind_of(DataMapper::Collection)
      end

      it 'should return an empty Collection' do
        @return.should be_empty
      end
    end

    describe 'when there is no child resource and the source is not saved' do
      before :all do
        @return = @car.__send__(@name)
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
        @return = nil

        @expected = @model.new
        @car.__send__("#{@name}=", [ @expected ])

        @return = @car.__send__(@name)
      end

      it 'should return a Collection' do
        @return.should be_kind_of(DataMapper::Collection)
      end

      it 'should return expected Resources' do
        @return.should == [ @expected ]
      end
    end

    describe 'when the target model is scoped' do
      before :all do
        2.times { @car.__send__(@name).new }
        @car.save

        @expected = @car.__send__(@name).first

        # set the model scope to only return the first record
        @model.default_scope.update(@model.key(@repository.name).zip(@expected.key).to_hash)

        @return = @car.model.get(*@car.key).__send__(@name)
      end

      it 'should return a Collection' do
        @return.should be_kind_of(DataMapper::Collection)
      end

      it 'should return expected Resources' do
        @return.should == [ @expected ]
      end
    end
  end
end

share_examples_for 'it creates a many mutator' do
  describe 'mutator' do
    describe 'when setting an Array of Resources' do
      before :all do
        @expected = [ @model.new ]

        @return = @car.__send__("#{@name}=", @expected)
      end

      it 'should return the expected Collection' do
        @return.should == @expected
      end

      it 'should set the Collection' do
        @car.__send__(@name).should == @expected
        @car.__send__(@name).zip(@expected) { |value, expected| value.should equal(expected) }
      end

      it 'should relate the associated Collection' do
        pending_if Car.relationships[@name].kind_of?(DataMapper::Associations::ManyToMany::Relationship) do
          @expected.each { |resource| resource.car.should == @car }
        end
      end

      it 'should persist the Collection' do
        @car.save.should be_true
        @car.model.get(*@car.key).__send__(@name).should == @expected
      end

      it 'should persist the associated Resource' do
        @car.save.should be_true
        @expected.each { |resource| resource.should be_saved }
        @expected.each { |resource| resource.model.get(*resource.key).car.should == @car }
      end
    end

    describe 'when setting an Array of Hashes' do
      before :all do
        attributes = { :id => 11 }
        @hashes    = [ attributes             ]
        @expected  = [ @model.new(attributes) ]

        @return = @car.__send__("#{@name}=", @hashes)
      end

      it 'should return the expected Collection' do
        @return.should == @expected
      end

      it 'should set the Collection' do
        @car.__send__(@name).should == @return
      end

      it 'should relate the associated Collection' do
        pending_if Car.relationships[@name].kind_of?(DataMapper::Associations::ManyToMany::Relationship) do
          @return.each { |resource| resource.car.should == @car }
        end
      end

      it 'should persist the Collection' do
        @car.save.should be_true
        @car.model.get(*@car.key).__send__(@name).should == @return
      end

      it 'should persist the associated Resource' do
        @car.save.should be_true
        @return.each { |resource| resource.should be_saved }
        @return.each { |resource| resource.model.get(*resource.key).car.should == @car }
      end
    end

    describe 'when setting an empty collection' do
      before :all do
        @car.__send__("#{@name}=", [ @model.new ])

        @return = @car.__send__("#{@name}=", [])
      end

      it 'should return a Collection' do
        @return.should be_kind_of(DataMapper::Collection)
      end

      it 'should set an empty Collection' do
        @car.__send__(@name).should be_empty
      end

      it 'should persist as an empty Collection' do
        @car.save.should be_true
        @car.model.get(*@car.key).__send__(@name).should be_empty
      end
    end

    describe 'when changing an associated collection' do
      before :all do
        @car.__send__("#{@name}=", [ @model.new ])

        @expected = [ @model.new ]

        @return = @car.__send__("#{@name}=", @expected)
      end

      it 'should return the expected Resource' do
        @return.should == @expected
      end

      it 'should set the Resource' do
        @car.__send__(@name).should == @expected
        @car.__send__(@name).zip(@expected) { |value, expected| value.should equal(expected) }
      end

      it 'should relate associated Resource' do
        pending_if Car.relationships[@name].kind_of?(DataMapper::Associations::ManyToMany::Relationship) do
          @expected.each { |resource| resource.car.should == @car }
        end
      end

      it 'should persist the Resource' do
        @car.save.should be_true
        @car.model.get(*@car.key).__send__(@name).should == @expected
      end

      it 'should persist the associated Resource' do
        @car.save.should be_true
        @expected.each { |resource| resource.should be_saved }
        @expected.each { |resource| resource.model.get(*resource.key).car.should == @car }
      end
    end
  end
end

describe DataMapper::Associations do
  before :all do
    class ::Car
      include DataMapper::Resource

      property :id, Serial
      property :name, String
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

  it { Engine.should respond_to(:belongs_to) }

  describe '#belongs_to' do
    before :all do
      @model = Engine
      @name  = :engine

      Car.belongs_to(@name, :required => false)
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
        describe 'querying for a parent resource when only the foreign key is set' do
          before :all do
            # create a car that would be returned if the query is not
            # scoped properly to retrieve @car
            Car.create

            @car = Car.create
            engine = Engine.new(:car_id => @car.id)

            @return = engine.car
          end

          it 'should return a Resource' do
            @return.should be_kind_of(DataMapper::Resource)
          end

          it 'should return expected Resource' do
            @return.should eql(@car)
          end
        end

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

            @engine = Engine.new(:car_id => @car.id)
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

    describe 'with a model' do
      before :all do
        Engine.belongs_to(:vehicle, Car)
      end

      it 'should set the relationship target model' do
        Engine.relationships[:vehicle].target_model.should == Car
      end
    end

    describe 'with a :model option' do
      before :all do
        Engine.belongs_to(:vehicle, :model => Car)
      end

      it 'should set the relationship target model' do
        Engine.relationships[:vehicle].target_model.should == Car
      end
    end

    describe 'with a single element as :child_key option' do
      before :all do
        Engine.belongs_to(:vehicle, :model => Car, :child_key => :bike_id)
      end

      it 'should set the relationship child key' do
        Engine.relationships[:vehicle].child_key.map { |property| property.name }.should == [:bike_id]
      end
    end

    describe 'with an array as :child_key option' do
      before :all do
        Engine.belongs_to(:vehicle, :model => Car, :child_key => [:bike_id])
      end

      it 'should set the relationship child key' do
        Engine.relationships[:vehicle].child_key.map { |property| property.name }.should == [:bike_id]
      end
    end

    describe 'with a single element as :parent_key option' do
      before :all do
        Engine.belongs_to(:vehicle, :model => Car, :parent_key => :name)
      end

      it 'should set the relationship parent key' do
        Engine.relationships[:vehicle].parent_key.map { |property| property.name }.should == [:name]
      end
    end

    describe 'with an array as :parent_key option' do
      before :all do
        Engine.belongs_to(:vehicle, :model => Car, :parent_key => [:name])
      end

      it 'should set the relationship parent key' do
        Engine.relationships[:vehicle].parent_key.map { |property| property.name }.should == [:name]
      end
    end
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

    describe '1 through' do
      before :all do
        @model = Engine
        @name  = :engine

        Car.has(1, @name, :through => DataMapper::Resource)
        Engine.has(1, :car, :through => DataMapper::Resource)
      end

      supported_by :all do
        before :all do
          @no_join = defined?(DataMapper::Adapters::InMemoryAdapter) && @adapter.kind_of?(DataMapper::Adapters::InMemoryAdapter) ||
                     defined?(DataMapper::Adapters::YamlAdapter)     && @adapter.kind_of?(DataMapper::Adapters::YamlAdapter)
        end

        before :all do
          @car = Car.new
        end

        before do
          pending if @no_join
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
        Door.belongs_to(:car, :required => false)
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

        Window.has(1, :car, :through => DataMapper::Resource)
        Car.has(1..4, :windows, :through => DataMapper::Resource)
      end

      supported_by :all do
        before :all do
          @no_join = defined?(DataMapper::Adapters::InMemoryAdapter) && @adapter.kind_of?(DataMapper::Adapters::InMemoryAdapter) ||
                     defined?(DataMapper::Adapters::YamlAdapter)     && @adapter.kind_of?(DataMapper::Adapters::YamlAdapter)
        end

        before :all do
          @car = Car.new
        end

        before do
          pending if @no_join
        end

        it { @car.should respond_to(@name) }

        it_should_behave_like 'it creates a many accessor'

        it { @car.should respond_to("#{@name}=") }

        it_should_behave_like 'it creates a many mutator'
      end
    end

    describe 'when the 3rd argument is a Model' do
      before :all do
        Car.has(1, :engine, Engine)
      end

      it 'should set the relationship target model' do
        Car.relationships[:engine].target_model.should == Engine
      end
    end

    describe 'when the 3rd argument is a String' do
      before :all do
        Car.has(1, :engine, 'Engine')
      end

      it 'should set the relationship target model' do
        Car.relationships[:engine].target_model.should == Engine
      end
    end

    it 'should raise an exception if the cardinality is not understood' do
      lambda { Car.has(n..n, :doors) }.should raise_error(ArgumentError)
    end

    it 'should raise an exception if the minimum constraint is larger than the maximum' do
      lambda { Car.has(2..1, :doors) }.should raise_error(ArgumentError)
    end
  end

  describe 'property prefix inference' do
    describe 'when a relationship has an inverse' do
      before :all do
        @engine_relationship = Car.has(1, :engine, :inverse => Engine.belongs_to(:sports_car, Car))
      end

      supported_by :all do
        it 'should have a child key prefix the same as the inverse relationship' do
          @engine_relationship.child_key.map { |property| property.name }.should == [ :sports_car_id ]
        end
      end
    end

    describe 'when a relationship does not have an inverse' do
      before :all do
        @engine_relationship = Car.has(1, :engine)
      end

      supported_by :all do
        it 'should have a child key prefix inferred from the source model name' do
          @engine_relationship.child_key.map { |property| property.name }.should == [ :car_id ]
        end
      end
    end

    describe 'when a relationship is inherited' do
      describe 'has an inverse' do
        before :all do
          Car.property(:type, DataMapper::Types::Discriminator)

          class ::ElectricCar < Car; end

          Car.has(1, :engine, :inverse => Engine.belongs_to(:sports_car, Car))
        end

        supported_by :all do
          before :all do
            @engine_relationship = ElectricCar.relationships(@repository.name)[:engine]
          end

          it 'should have a source model equal to the ancestor' do
            @engine_relationship.source_model.should equal(Car)
          end

          it 'should have a child key prefix the same as the inverse relationship' do
            @engine_relationship.child_key.map { |property| property.name }.should == [ :sports_car_id ]
          end
        end
      end

      describe 'does not have an inverse' do
        before :all do
          Car.property(:type, DataMapper::Types::Discriminator)

          class ::ElectricCar < Car; end

          Car.has(1, :engine)
        end

        supported_by :all do
          before :all do
            @engine_relationship = ElectricCar.relationships(@repository.name)[:engine]
          end

          it 'should have a source model equal to the ancestor' do
            @engine_relationship.source_model.should equal(Car)
          end

          it 'should have a child key prefix inferred from the source model name' do
            @engine_relationship.child_key.map { |property| property.name }.should == [ :car_id ]
          end
        end
      end
    end

    describe "when a subclass defines it's own relationship" do
      describe 'has an inverse' do
        before :all do
          Car.property(:type, DataMapper::Types::Discriminator)

          class ::ElectricCar < Car; end

          ElectricCar.has(1, :engine, :inverse => Engine.belongs_to(:sports_car, Car))
        end

        supported_by :all do
          before :all do
            @engine_relationship = ElectricCar.relationships(@repository.name)[:engine]
          end

          it 'should have a source model equal to the descendant' do
            @engine_relationship.source_model.should equal(ElectricCar)
          end

          it 'should have a child key prefix the same as the inverse relationship' do
            @engine_relationship.child_key.map { |property| property.name }.should == [ :sports_car_id ]
          end
        end
      end

      describe 'does not have an inverse' do
        before :all do
          Car.property(:type, DataMapper::Types::Discriminator)

          class ::ElectricCar < Car; end

          ElectricCar.has(1, :engine)
        end

        supported_by :all do
          before :all do
            @engine_relationship = ElectricCar.relationships(@repository.name)[:engine]
          end

          it 'should have a source model equal to the descendant' do
            @engine_relationship.source_model.should equal(ElectricCar)
          end

          it 'should have a child key prefix inferred from the source model name' do
            @engine_relationship.child_key.map { |property| property.name }.should == [ :electric_car_id ]
          end
        end
      end
    end
  end

  describe 'child is also a parent' do
    before :all do
      class ::Employee
        include DataMapper::Resource

        property :id,   Serial
        property :name, String

        belongs_to :company
      end

      class ::Company
        include DataMapper::Resource

        property :id,   Serial
        property :name, String

        belongs_to :owner, Employee, :required => false
        has n, :employees
      end
    end

    supported_by :all do
      before :all do
        @company  = Company.create(:name => 'ACME Inc.')
        @employee = @company.employees.create(:name => 'Wil E. Coyote')
      end

      it 'should save the child as a parent' do
        lambda {
          @company.owner = @employee
          @company.save.should be_true
        }.should_not raise_error
      end
    end
  end
end
