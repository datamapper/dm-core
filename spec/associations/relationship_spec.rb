require 'pathname'
require Pathname(__FILE__).dirname.expand_path.parent + 'spec_helper'

describe DataMapper::Associations::Relationship do

  before do
    @adapter = DataMapper::Repository.adapters[:relationship_spec] || DataMapper.setup(:relationship_spec, 'mock://localhost')
  end
  
  it "should describe an association" do
    belongs_to = DataMapper::Associations::Relationship.new(
      :manufacturer,
      :relationship_spec,
      ['Vehicle', [:manufacturer_id]],
      ['Manufacturer', nil]
      )
    
    belongs_to.should respond_to(:name)
    belongs_to.should respond_to(:repository_name)
    belongs_to.should respond_to(:source)
    belongs_to.should respond_to(:target)
    
    belongs_to.name.should == :manufacturer
    belongs_to.repository_name.should == :relationship_spec
    
    belongs_to.source.should be_a_kind_of(Array)
    belongs_to.target.should be_a_kind_of(Array)

    belongs_to.source.should == Vehicle.properties(:relationship_spec).select(:manufacturer_id)
    belongs_to.target.should == Manufacturer.properties(:relationship_spec).key
  end

end
