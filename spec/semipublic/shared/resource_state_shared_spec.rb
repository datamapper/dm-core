share_examples_for 'A method that delegates to the superclass #set' do
  it 'should delegate to the superclass' do
    # this is the only way I could think of to test if the
    # superclass method is being called
    DataMapper::Resource::State.class_eval { alias_method :original_set, :set; undef_method(:set) }
    method(:subject).should raise_error(NoMethodError)
    DataMapper::Resource::State.class_eval { alias_method :set, :original_set; undef_method(:original_set) }
  end
end

share_examples_for 'A method that does not delegate to the superclass #set' do
  it 'should delegate to the superclass' do
    # this is the only way I could think of to test if the
    # superclass method is not being called
    DataMapper::Resource::State.class_eval { alias_method :original_set, :set; undef_method(:set) }
    method(:subject).should_not raise_error(NoMethodError)
    DataMapper::Resource::State.class_eval { alias_method :set, :original_set; undef_method(:original_set) }
  end
end

share_examples_for 'It resets resource state' do
  it 'should reset the dirty property' do
    method(:subject).should change(@resource, :name).from('John Doe').to('Dan Kubb')
  end

  it 'should reset the dirty m:1 relationship' do
    method(:subject).should change(@resource, :parent).from(@resource).to(nil)
  end

  it 'should reset the dirty 1:m relationship' do
    method(:subject).should change(@resource, :children).from([ @resource ]).to([])
  end

  it 'should clear original attributes' do
    method(:subject).should change { @resource.original_attributes.dup }.to({})
  end
end

share_examples_for 'Resource::State::Persisted#get' do
  subject { @state.get(@key) }

  supported_by :all do
    describe 'with an unloaded subject' do
      before do
        @key = @model.relationships[:parent]

        # set the parent relationship
        @resource.attributes = { @key => @resource }
        @resource.should be_dirty
        @resource.save.should be(true)

        attributes = DataMapper::Ext::Array.to_hash(@model.key.zip(@resource.key))
        @resource = @model.first(attributes.merge(:fields => @model.key))
        @state    = @state.class.new(@resource)

        # make sure the subject is not loaded
        @key.should_not be_loaded(@resource)
      end

      it 'should lazy load the value' do
        subject.key.should == @resource.key
      end
    end

    describe 'with a loaded subject' do
      before do
        @key           = @model.properties[:name]
        @loaded_value ||= 'Dan Kubb'

        # make sure the subject is loaded
        @key.should be_loaded(@resource)
      end

      it 'should return value' do
        should == @loaded_value
      end
    end
  end
end
