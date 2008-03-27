require 'pathname'
require Pathname(__FILE__).dirname.expand_path.parent + 'spec_helper'

describe DataMapper::Associations::Relationship do

  before do
    @adapter = DataMapper::Repository.adapters[:relationship_spec] || DataMapper.setup(:relationship_spec, 'mock://localhost')
  end
  
  it "should describe an asociation" do
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
  end
  
  it "should map properties explicitly when an association method passes them in it's options" do
    belongs_to = DataMapper::Associations::Relationship.new(
      :manufacturer,
      :relationship_spec,
      ['Vehicle', [:manufacturer_id]],
      ['Manufacturer', [:id]]
      )
    
    belongs_to.name.should == :manufacturer
    belongs_to.repository_name.should == :relationship_spec
    
    belongs_to.source.should be_a_kind_of(Array)
    belongs_to.target.should be_a_kind_of(Array)

    belongs_to.source.should == Vehicle.properties(:relationship_spec).select(:manufacturer_id)
    belongs_to.target.should == Manufacturer.properties(:relationship_spec).key
  end
  
  it "should infer properties when options aren't passed" do
    has_many = DataMapper::Associations::Relationship.new(
      :manufacturer,
      :relationship_spec,
      ['Vehicle', nil],
      ['Manufacturer', nil]
      )
    
    has_many.name.should == :manufacturer
    has_many.repository_name.should == :relationship_spec
    
    has_many.source.should be_a_kind_of(Array)
    has_many.target.should be_a_kind_of(Array)

    has_many.source.should == Vehicle.properties(:relationship_spec).select(:manufacturer_id)
    has_many.target.should == Manufacturer.properties(:relationship_spec).key
  end

end
