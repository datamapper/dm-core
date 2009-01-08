share_examples_for 'An Adapter' do
  before do
    %w[ @adapter @model @string_property @integer_property ].each do |ivar|
      raise "+#{ivar}+ should be defined in before block" unless instance_variable_get(ivar)
    end

    @resource = @model.new(:color => 'Mauve')
  end

  it { @adapter.should respond_to(:create) }

  describe '#create' do
    before do
      @return = @adapter.create([@resource])
    end

    it 'should return the number of records created' do
      @return.should == 1
    end

    it 'should set the identity field for the resource' do
      @resource.id.should_not be_nil
    end
  end

  it { @adapter.should respond_to(:update) }

  describe '#update' do
    before do
      @resource.save
      @return = @adapter.update({@string_property => 'red'}, DataMapper::Query.new(@repository, @model, @model.key.zip(@resource.key).to_hash))
    end

    it 'should return the number of records that were updated' do
      @return.should == 1
    end

    it 'should update the specified properties' do
      @resource.reload.color.should == 'red'
    end
  end

  it { @adapter.should respond_to(:read_one) }

  describe '#read_one' do
    before do
      @resource.save
      @return = @adapter.read_one(DataMapper::Query.new(@repository, @model, :id => @resource.id))
    end

    it 'should return a DataMapper::Resource' do
      @return.should be_a_kind_of(@model)
    end

    it 'should return nil when no resource was found' do
      @adapter.read_one(DataMapper::Query.new(@repository, @model, :id => nil)).should be_nil
    end
  end

  it { @adapter.should respond_to(:read_many) }

  describe '#read_many' do
    before do
      @resource.save
      @return = @adapter.read_many(DataMapper::Query.new(@repository, @model, :id => @resource.id))
    end

    it 'should return an Array' do
      @return.should be_a_kind_of(Array)
    end

    it 'should return the requested resource' do
      @return.should include(@resource)
    end
  end

  it { @adapter.should respond_to(:delete) }

  describe '#delete' do
    before do
      @resource.save
      @return = @adapter.delete(DataMapper::Query.new(@repository, @model, :id => @resource.id))
    end

    it 'should return the number of records deleted' do
      @return.should == 1
    end

    it 'should delete the requested resource' do
      @model.get(@resource.id).should be_nil
    end
  end

  describe 'conditions' do
    before do
      @red = @model.create(@string_property.name => 'red')
      @two = @model.create(@integer_property.name => 2)
      @five = @model.create(@integer_property.name => 5)
    end

    describe 'eql' do
      it 'should be able to search for objects included in an inclusive range of values' do
        @model.all(@integer_property.name => 1..5).should include(@five)
      end

      it 'should be able to search for objects included in an exclusive range of values' do
        @model.all(@integer_property.name => 1...6).should include(@five)
      end

      it 'should not be able to search for values not included in an inclusive range of values' do
        @model.all(@integer_property.name => 1..4).should_not include(@five)
      end

      it 'should not be able to search for values not included in an exclusive range of values' do
        @model.all(@integer_property.name => 1...5).should_not include(@five)
      end
    end

    describe 'not' do
      it 'should be able to search for objects with not equal value' do
        @model.all(@string_property.name.not => 'red').should_not include(@blue)
      end

      it 'should include objects that are not like the value' do
        @model.all(@string_property.name.not => 'black').should include(@red)
      end

      it 'should be able to search for objects with not nil value' do
        @model.all(@string_property.name.not => nil).should include(@red)
      end

      it 'should not include objects with a nil value' do
        @model.all(@string_property.name.not => nil).should_not include(@two)
      end

      it 'should be able to search for objects not included in an array of values' do
        @model.all(@integer_property.name.not => [ 1, 3, 5, 7 ]).should include(@two)
      end

      it 'should be able to search for objects not included in an array of values' do
        @model.all(@integer_property.name.not => [ 1, 3, 5, 7 ]).should_not include(@five)
      end

      it 'should be able to search for objects not included in an inclusive range of values' do
        @model.all(@integer_property.name.not => 1..4).should include(@five)
      end

      it 'should be able to search for objects not included in an exclusive range of values' do
        @model.all(@integer_property.name.not => 1...5).should include(@five)
      end

      it 'should not be able to search for values not included in an inclusive range of values' do
        @model.all(@integer_property.name.not => 1..5).should_not include(@five)
      end

      it 'should not be able to search for values not included in an exclusive range of values' do
        @model.all(@integer_property.name.not => 1...6).should_not include(@five)
      end
    end

    describe 'like' do
      it 'should be able to search for objects that match value' do
        @model.all(@string_property.name.like => /ed/).should include(@red)
      end

      it 'should not search for objects that do not match the value' do
        @model.all(@string_property.name.like => /blak/).should_not include(@red)
      end
    end

    describe 'gt' do
      it 'should be able to search for objects with value greater than' do
        @model.all(@integer_property.name.gt => 1).should include(@two)
      end

      it 'should not find objects with a value less than' do
        @model.all(@integer_property.name.gt => 3).should_not include(@two)
      end
    end

    describe 'gte' do
      it 'should be able to search for objects with value greater than' do
        @model.all(@integer_property.name.gte => 1).should include(@two)
      end

      it 'should be able to search for objects with values equal to' do
        @model.all(@integer_property.name.gte => 2).should include(@two)
      end

      it 'should not find objects with a value less than' do
        @model.all(@integer_property.name.gte => 3).should_not include(@two)
      end
    end

    describe 'lt' do
      it 'should be able to search for objects with value less than' do
        @model.all(@integer_property.name.lt => 3).should include(@two)
      end

      it 'should not find objects with a value less than' do
        @model.all(@integer_property.name.gt => 2).should_not include(@two)
      end
    end

    describe 'lte' do
      it 'should be able to search for objects with value less than' do
        @model.all(@integer_property.name.lte => 3).should include(@two)
      end

      it 'should be able to search for objects with values equal to' do
        @model.all(@integer_property.name.lte => 2).should include(@two)
      end

      it 'should not find objects with a value less than' do
        @model.all(@integer_property.name.lte => 1).should_not include(@two)
      end
    end
  end

  describe 'limits' do
    it 'should be able to limit the objects' do
      @model.all(:limit => 2).length.should == 2
    end
  end
end
