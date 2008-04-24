require 'pathname'
require Pathname(__FILE__).dirname.expand_path.parent + 'spec_helper'

describe "DataMapper::Associations" do
  before :each do
    @relationship = mock(DataMapper::Associations::Relationship)
    @n = 1.0/0
  end

  describe ".has" do

    it "should allow a declaration" do
      lambda do
        class Manufacturer
          has 1, :halo_car
        end
      end.should_not raise_error
    end

    it "should not allow a constraint that is not a Range, Fixnum, Bignum or Infinity" do
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
      Manufacturer.should_receive(:one_to_many).
        with(:vehicles, {:min=>1, :max=>2}).
        and_return(@relationship)
      class Manufacturer
        has 1..2, :vehicles, :min=>5, :max=>10
      end
    end

    describe "one-to-one syntax" do
      it "should create a basic one-to-one association with fixed constraint" do
        Manufacturer.should_receive(:one_to_one).
          with(:halo_car, { :min => 1, :max => 1 }).
          and_return(@relationship)
        class Manufacturer
          has 1, :halo_car
        end
      end

      it "should create a basic one-to-one association with min/max constraints" do
        Manufacturer.should_receive(:one_to_one).
          with(:halo_car, { :min => 0, :max => 1 }).
          and_return(@relationship)
        class Manufacturer
          has 0..1, :halo_car
        end
      end

      it "should create a one-to-one association with options" do
        Manufacturer.should_receive(:one_to_one).
          with(:halo_car, {:class_name => 'Car', :min => 1, :max => 1 }).
          and_return(@relationship)
        class Manufacturer
          has 1, :halo_car,
            :class_name => 'Car'
        end
      end
    end

    describe "one-to-many syntax" do
      it "should create a basic one-to-many association with no constraints" do
        Manufacturer.should_receive(:one_to_many).
          with(:vehicles,{}).
          and_return(@relationship)
        class Manufacturer
          has n, :vehicles
        end
      end

      it "should create a one-to-many association with fixed constraint" do
        Manufacturer.should_receive(:one_to_many).
          with(:vehicles,{:min=>4, :max=>4}).
          and_return(@relationship)
        class Manufacturer
          has 4, :vehicles
        end
      end

      it "should create a one-to-many association with min/max constraints" do
        Manufacturer.should_receive(:one_to_many).
          with(:vehicles,{:min=>2, :max=>4}).
          and_return(@relationship)
        class Manufacturer
          has 2..4, :vehicles
        end
      end

      it "should create a one-to-many association with options" do
        Manufacturer.should_receive(:one_to_many).
          with(:vehicles,{:min=>1, :max=>@n, :class_name => 'Car'}).
          and_return(@relationship)
        class Manufacturer
          has 1..n, :vehicles,
            :class_name => 'Car'
        end
      end

      it "should create a many-to-many relationship if references are circular" do
        # ================
          pending
        # ================
      end

      it "should create one-to-many association and pass the :through option if specified" do
        Vehicle.should_receive(:one_to_many).
          with(:suppliers,{:through => :manufacturers}).
          and_return(@relationship)
        class Vehicle
          has n, :suppliers, :through => :manufacturers
        end
      end
    end
  end

  describe ".belongs_to" do
    it "should create a basic many-to-one association" do
      Manufacturer.should_receive(:many_to_one).
        with(:vehicle,{}).
        and_return(@relationship)
      class Manufacturer
        belongs_to :vehicle
      end
    end

    it "should create a many-to-one association with options" do
      Manufacturer.should_receive(:many_to_one).
        with(:vehicle,{:class_name => 'Car'}).
        and_return(@relationship)
      class Manufacturer
        belongs_to :vehicle,
          :class_name => 'Car'
      end
    end
  end
end
