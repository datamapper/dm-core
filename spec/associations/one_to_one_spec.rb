require 'pathname'
require Pathname(__FILE__).dirname.expand_path.parent + 'spec_helper'
require __DIR__.parent.parent + 'lib/data_mapper/associations/one_to_one'

describe "DataMapper::Associations::OneToOne" do

  it "should allow a declaration" do
    lambda do
      class Manufacturer
        one_to_one :halo_car, :class => 'Vehicle'
      end
    end.should_not raise_error
  end
end
