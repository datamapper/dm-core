require 'pathname'
require Pathname(__FILE__).dirname.expand_path.parent + 'spec_helper'

describe "DataMapper::Associations::HasOne" do

  before do
    @adapter = DataMapper::Repository.adapters[:relationship_spec] || DataMapper.setup(:relationship_spec, 'mock://localhost')
  end
    
  it "should allow a declaration" do
    
    lambda do
      class Manufacturer
        has_one :halo_car, :class => 'Vehicle'
      end
    end.should_not raise_error
  end
  
end