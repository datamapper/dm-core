require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'spec_helper'))

describe DataMapper::Associations::Relationship do
  it "should describe an association" do
    belongs_to = DataMapper::Associations::Relationship.new(
      :manufacturer,
      :mock,
      'Vehicle',
      'Manufacturer',
      { :child_key => [ :manufacturer_id ] }
    )

    belongs_to.should respond_to(:name)
    belongs_to.should respond_to(:repository_name)
    belongs_to.should respond_to(:child_key)
    belongs_to.should respond_to(:parent_key)
  end

  it "should map properties explicitly when an association method passes them in its options" do
    repository_name = :mock

    belongs_to = DataMapper::Associations::Relationship.new(
      :manufacturer,
      repository_name,
      'Vehicle',
      'Manufacturer',
      { :child_key => [ :manufacturer_id ], :parent_key => [ :id ] }
    )

    belongs_to.name.should == :manufacturer
    belongs_to.repository_name.should == repository_name

    belongs_to.child_key.should be_a_kind_of(DataMapper::PropertySet)
    belongs_to.parent_key.should be_a_kind_of(DataMapper::PropertySet)

    belongs_to.child_key.to_a.should == Vehicle.properties(repository_name).slice(:manufacturer_id)
    belongs_to.parent_key.to_a.should == Manufacturer.properties(repository_name).key
  end

  it "should infer properties when options aren't passed" do
    repository_name = :mock

    has_many = DataMapper::Associations::Relationship.new(
      :models,
      repository_name,
      'Vehicle',
      'Manufacturer',
      { :child_key => [:model_id] }
    )

    has_many.name.should == :models
    has_many.repository_name.should == repository_name

    has_many.child_key.should be_a_kind_of(DataMapper::PropertySet)
    has_many.parent_key.should be_a_kind_of(DataMapper::PropertySet)
    # Vehicle.has n, :models, :class_name => 'Manufacturer', :child_key => "models_id"
    has_many.child_key.to_a.should == Vehicle.properties(repository_name).slice(:model_id)
    has_many.parent_key.to_a.should == Manufacturer.properties(repository_name).key
  end

  it "should generate child properties with a safe subset of the parent options" do
    pending
    # For example, :size would be an option you'd want a generated child Property to copy,
    # but :serial or :key obviously not. So need to take a good look at Property::OPTIONS to
    # see what applies and what doesn't.
  end

end
