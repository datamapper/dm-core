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
      :models,
      :relationship_spec,
      ['Vehicle', nil],
      ['Manufacturer', nil]
      )
    
    has_many.name.should == :models
    has_many.repository_name.should == :relationship_spec
    
    has_many.source.should be_a_kind_of(Array)
    has_many.target.should be_a_kind_of(Array)

    has_many.source.should == Vehicle.properties(:relationship_spec).select(:models_id)
    has_many.target.should == Manufacturer.properties(:relationship_spec).key
  end
  
  it "should generate source properties with a safe subset of the target options" do
    pending
    # For example, :size would be an option you'd want a generated source Property to copy,
    # but :serial or :key obviously not. So need to take a good look at Property::OPTIONS to
    # see what applies and what doesn't.
  end

end

__END__
class LazyLoadedSet < LoadedSet

  def initialize(*args, &b)
    super(*args)
    @on_demand_loader = b
  end
  
  def each
    @on_demand_loader[self]
    class << self
      def each
        super
      end
    end
    
    super
  end

end

set = LazyLoadedSet.new(repository, Zoo, { Property<:id> => 1, Property<:name> => 2, Property<:notes> => 3 }) do |lls|
  connection = create_connection
  command = connection.create_command("SELECT id, name, notes FROM zoos")
  command.set_types([Fixnum, String, String])
  reader = command.execute_reader
  
  while(reader.next!)
    lls.materialize!(reader.values)
  end

  reader.close  
  connection.close
end

class AssociationSet
  
  def initialize(relationship)
    @relationship = relationship
  end
  
  def each
    # load some stuff
  end
  
  def <<(value)
    # add some stuff and track it.
  end
end

class Vehicle
  belongs_to :manufacturer
  
  def manufacturer
    manufacturer_association_set.first
  end
  
  def manufacturer=(value)
    manufacturer_association_set.set(value)
  end
  
  private
  # This is all class-evaled code defined by belongs_to:
  def manufacturer_association_set
    @manufacturer_association_set || 
      @manufacturer_association_set = AssociationSet.new(
        self.class.associations(repository.name).detect(:manufacturer)
      ) do |set|
        # This block is the part that will change between different associations.

        # Target is the Array of PK properties remember.
        resource = set.relationship.target.first.resource
        
        resource.all(resource.key => self.loaded_set.keys)
    end
  end
  
end
