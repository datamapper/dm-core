share_examples_for 'An Adapter' do
  before do
    %w[ @adapter @resource @model @property ].each do |ivar|
      raise "+#{ivar}+ should be defined in before block" unless instance_variable_get(ivar)
    end
  end

  it "should respond to create" do
    @adapter.should respond_to(:create)
  end

  describe "#create" do
    before do
      @return = @adapter.create([@resource])
    end

    it "should return the number of records created" do
      @return.should == 1
    end

    it "should set the identity field for the resource" do
      @resource.id.should_not be_nil
    end
  end

  it "should respond to update" do
    @adapter.should respond_to(:update)
  end

  describe "#update" do
    before do
      @resource.save
      @return = @adapter.update({@property => "red"}, DataMapper::Query.new(@repository, @model, :id => @resource.id))
    end

    it "should return the number of records that were updated" do
      @return.should == 1
    end

    it "should update the specified properties" do
      @resource.reload.color.should == "red"
    end
  end

  it "should respond to read_one" do
    @adapter.should respond_to(:read_one)
  end

  describe "#read_one" do
    before do
      @resource.save
      @return = @adapter.read_one(DataMapper::Query.new(@repository, @model, :id => @resource.id))
    end

    it "should return a DataMapper::Resource" do
      @return.should be_a_kind_of(@model)
    end

    it "should return nil when no resource was found" do
      @adapter.read_one(DataMapper::Query.new(@repository, @model, :id => nil)).should be_nil
    end
  end

  it "should respond to read_many" do
    @adapter.should respond_to(:read_many)
  end

  describe "#read_many" do
    before do
      @resource.save
      @return = @adapter.read_many(DataMapper::Query.new(@repository, @model, :id => @resource.id))
    end

    it "should return a DataMapper::Collection" do
      @return.should be_a_kind_of(DataMapper::Collection)
    end

    it "should return the requested resource" do
      @return.should include(@resource)
    end
  end

  it "should respond to delete" do
    @adapter.should respond_to(:delete)
  end

  describe "#delete" do
    before do
      @resource.save
      @return = @adapter.delete(DataMapper::Query.new(@repository, @model, :id => @resource.id))
    end

    it "should return the number of records deleted" do
      @return.should == 1
    end

    it "should delete the requested resource" do
      @model.get(@resource.id).should be_nil
    end
  end
end
