require 'pathname'
require Pathname(__FILE__).dirname.expand_path.parent + 'spec_helper'

require ROOT_DIR + 'lib/data_mapper/associations.rb'

describe "DataMapper::Associations" do
  before :each do
    @relationship = mock(DataMapper::Associations::Relationship)
    @n = 1.0/0
  end

  describe ".has" do
    it "should allow a declaration" do
      lambda do
        class Manufacturer
          has :halo_car, 1
        end
      end.should_not raise_error
    end

    describe "one-to-one syntax" do
      it "should create a basic one-to-one association" do
        Manufacturer.should_receive(:one_to_one).
          with(:halo_car,{}).
          and_return(@relationship)
        class Manufacturer
          has :halo_car, 1
        end
      end

      it "should create a one-to-one association with options" do
        Manufacturer.should_receive(:one_to_one).
          with(:halo_car, {:class_name => 'Car', :repository_name => 'other'}).
          and_return(@relationship)
        class Manufacturer
          has :halo_car, 1, 
            :class_name => 'Car',
            :repository_name => 'other'
        end
      end
    end
    
    describe "one-to-many syntax" do
      it "should create a basic one-to-many association with no constraints" do
        Manufacturer.should_receive(:one_to_many).
          with(:vehicles,{:min=>0, :max=>@n}).
          and_return(@relationship)
        class Manufacturer
          has :vehicles, 0..n
        end
      end
      
      it "should create a one-to-many association with constraints" do
        Manufacturer.should_receive(:one_to_many).
          with(:vehicles,{:min=>2, :max=>4}).
          and_return(@relationship)
        class Manufacturer
          has :vehicles, 2..4
        end
      end

      it "should create a one-to-many association with options" do
        Manufacturer.should_receive(:one_to_many).
          with(:vehicles,{:min=>1, :max=>@n, :class_name => 'Car'}).
          and_return(@relationship)
        class Manufacturer
          has :vehicles, 1..n,
            :class_name => 'Car'
        end
      end
    end
    
    describe "many-to-one syntax" do
      it "should create a basic many-to-one association with no constraints" do
        Manufacturer.should_receive(:many_to_one).
          with(:vehicles,{:min=>0, :max=>@n}).
          and_return(@relationship)
        class Manufacturer
          has :vehicles, n..0
        end
      end
      
      it "should create a many-to-one association with constraints" do
        Manufacturer.should_receive(:many_to_one).
          with(:vehicles,{:min=>2, :max=>4}).
          and_return(@relationship)
        class Manufacturer
          has :vehicles, 4..2
        end
      end

      it "should create a many-to-one association with options" do
        Manufacturer.should_receive(:many_to_one).
          with(:vehicles,{:min=>1, :max=>@n, :class_name => 'Car'}).
          and_return(@relationship)
        class Manufacturer
          has :vehicles, n..1,
            :class_name => 'Car'
        end
      end
    end
  end
end

