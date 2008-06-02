require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

describe "DataMapper::Associations" do
  before :each do
    @relationship = mock(DataMapper::Associations::Relationship)
    @n = 1.0/0
  end

  describe ".relationships" do
    class B
      include DataMapper::Resource
    end

    class C
      include DataMapper::Resource

      repository(:mock) do
        has 1, :b
      end
    end

    class D
      include DataMapper::Resource
      has 1, :b
    end

    class E < D
    end

    class F < D
      has 1, :a
    end

    it "should assume the default repository when no arguments are passed" do
      lambda do
        C.relationships
      end.should_not raise_error
    end

    it "should return the right set of relationships given the repository name" do
      C.relationships.should be_empty
      C.relationships(:mock).should_not be_empty
    end

    it "should return the right set of relationships given the inheritance" do
      E.relationships.should have(1).entries
      D.relationships.should have(1).entries
      F.relationships.should have(2).entries
    end
  end

  describe ".has" do

    it "should allow a declaration" do
      lambda do
        class Manufacturer
          has 1, :halo_car
        end
      end.should_not raise_error
    end

    it "should not allow a constraint that is not an Integer, Range or Infinity" do
      lambda do
        class Manufacturer
          has '1', :halo_car
        end
      end.should raise_error(ArgumentError)
    end

    it "should not allow a constraint where the min is larger than the max" do
      lambda do
        class Manufacturer
          has 1..0, :halo_car
        end
      end.should raise_error(ArgumentError)
    end

    it "should not allow overwriting of the auto assigned min/max values with keys" do
      DataMapper::Associations::OneToMany.should_receive(:setup).
        with(:vehicles, Manufacturer, {:min=>1, :max=>2}).
        and_return(@relationship)
      class Manufacturer
        has 1..2, :vehicles, :min=>5, :max=>10
      end
    end

    describe "one-to-one syntax" do
      it "should create a basic one-to-one association with fixed constraint" do
        DataMapper::Associations::OneToOne.should_receive(:setup).
          with(:halo_car, Manufacturer, { :min => 1, :max => 1 }).
          and_return(@relationship)
        class Manufacturer
          has 1, :halo_car
        end
      end

      it "should create a basic one-to-one association with min/max constraints" do
        DataMapper::Associations::OneToOne.should_receive(:setup).
          with(:halo_car, Manufacturer, { :min => 0, :max => 1 }).
          and_return(@relationship)
        class Manufacturer
          has 0..1, :halo_car
        end
      end

      it "should create a one-to-one association with options" do
        DataMapper::Associations::OneToOne.should_receive(:setup).
          with(:halo_car, Manufacturer, { :class_name => 'Car', :min => 1, :max => 1 }).
          and_return(@relationship)
        class Manufacturer
          has 1, :halo_car,
            :class_name => 'Car'
        end
      end
    end

    describe "one-to-many syntax" do
      it "should create a basic one-to-many association with no constraints" do
        DataMapper::Associations::OneToMany.should_receive(:setup).
          with(:vehicles, Manufacturer, {}).
          and_return(@relationship)
        class Manufacturer
          has n, :vehicles
        end
      end

      it "should create a one-to-many association with fixed constraint" do
        DataMapper::Associations::OneToMany.should_receive(:setup).
          with(:vehicles, Manufacturer, { :min => 4, :max => 4 }).
          and_return(@relationship)
        class Manufacturer
          has 4, :vehicles
        end
      end

      it "should create a one-to-many association with min/max constraints" do
        DataMapper::Associations::OneToMany.should_receive(:setup).
          with(:vehicles, Manufacturer, { :min => 2, :max => 4 }).
          and_return(@relationship)
        class Manufacturer
          has 2..4, :vehicles
        end
      end

      it "should create a one-to-many association with options" do
        DataMapper::Associations::OneToMany.should_receive(:setup).
          with(:vehicles, Manufacturer, { :min => 1, :max => @n, :class_name => 'Car' }).
          and_return(@relationship)
        class Manufacturer
          has 1..n, :vehicles,
            :class_name => 'Car'
        end
      end

      # do not remove or change this spec.
      it "should raise an exception when n..n is used for the cardinality" do
        lambda do
          class Manufacturer
            has n..n, :subsidiaries, :class_name => 'Manufacturer'
          end
        end.should raise_error(ArgumentError)
      end

      it "should create one-to-many association and pass the :through option if specified" do
        DataMapper::Associations::OneToMany.should_receive(:setup).
          with(:suppliers, Vehicle, { :through => :manufacturers }).
          and_return(@relationship)
        class Vehicle
          has n, :suppliers, :through => :manufacturers
        end
      end
    end
  end

  describe ".belongs_to" do
    it "should create a basic many-to-one association" do
      DataMapper::Associations::ManyToOne.should_receive(:setup).
        with(:vehicle, Manufacturer, {}).
        and_return(@relationship)
      class Manufacturer
        belongs_to :vehicle
      end
    end

    it "should create a many-to-one association with options" do
      DataMapper::Associations::ManyToOne.should_receive(:setup).
        with(:vehicle, Manufacturer, { :class_name => 'Car' }).
        and_return(@relationship)
      class Manufacturer
        belongs_to :vehicle,
          :class_name => 'Car'
      end
    end
  end
end
