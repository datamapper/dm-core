share_examples_for 'A Resource' do
  before do
    %w[ @model @user @child_model ].each do |ivar|
      raise "+#{ivar}+ should be defined in before block" unless instance_variable_get(ivar)
    end
  end

  it 'should respond to #save' do
    @user.should respond_to(:save)
  end

  describe '#save' do

    describe 'on a not dirty object' do

      it 'should return true even when resource is not dirty' do
        @user.save.should be_true
      end

    end

    describe 'on a dirty object' do

      before do
        @user.age = 26
        @return = @user.save
      end

      it 'should save a resource succesfully when dirty' do
        @return.should be_true
      end

      it 'should actually store the changes to persistent storage' do
        skip_class = DataMapper::Associations::ManyToOne::Proxy
        pending_if "TODO: update #{skip_class}#save to actually save the object", @user.kind_of?(skip_class) do
          @user.attributes.should == @model.get(*@user.key).attributes
        end
      end
    end

    describe 'on a dirty invalid object' do

      before do
        @user.name = nil
      end

      it 'should not save an invalid resource' do
        pending "it raises an exception when trying to save a non serial nil key" do
          @user.save.should be_false
        end
      end

    end

    describe 'with new resources in a has relationship' do

      before do
        @initial_comments = @user.comments.size
        @first_comment    = @user.comments.build(:body => "DM is great!")
        @second_comment   = @child_model.new(:user => @user, :body => "is it really?")
        @return           = @user.save
      end

      it 'should save resource' do
        @return.should be_true
      end

      it 'should save the first resource created through build' do
        skip_class = DataMapper::Associations::ManyToOne::Proxy
        pending_if "TODO: update #{skip_class}#save to actually save the object", @user.kind_of?(skip_class) do
          @first_comment.new_record?.should be_false
        end
      end

      it 'should save the correct foreign key for the first resource' do
        @first_comment.user.should eql(@user)
      end

      it 'should save the second resource created through the constructor' do
        pending "Changing a belongs_to parent should add the object to the correct association" do
          @second_comment.new_record?.should be_false
        end
      end

      it 'should save the correct foreign key for the second resource' do
        @second_comment.user.should eql(@user)
      end

      it 'should create 2 extra resources in persistent storage' do
        pending "Changing a belongs_to parent should add the object to the correct association" do
          @user.comments.size.should == @initial_comments + 2
        end
      end

    end

    describe 'with dirty resources in a has relationship' do

      before do
        @initial_comments = @user.comments.size
        @first_comment    = @user.comments.create(:body => "DM is great!")
        @second_comment   = @child_model.create(:user => @user, :body => "is it really?")

        @first_comment.body  = "It still has rough edges"
        @second_comment.body = "But these cool specs help fixing that"
        @second_comment.user = @model.create(:name => 'dkubb')
        @return              = @user.save
      end

      it 'should save the dirty resources' do
        @return.should be_true
      end

      it 'should have saved the first child resource' do
        skip_class = DataMapper::Associations::ManyToOne::Proxy
        pending_if "TODO: update #{skip_class}#save to actually save the object", @user.kind_of?(skip_class) do
          @first_comment.should_not be_dirty
        end
      end

      it 'should not have saved the second child resource' do
        @second_comment.should be_dirty
      end

    end

    describe 'with a new parent object' do

      before do
        @first_comment      = Comment.new(:body => "DM is great!")
        @first_comment.user = @model.new(:name => 'dkubb')
      end

      it 'should raise an exception when saving the resource' do
        pending "it should raise an exception when a parent is not persisted" do
          lambda { @first_comment.save }.should raise_error
        end
      end

    end

    describe 'with a dirty parent object' do

      before do
        @first_comment = @user.comments.build(:body => "DM is great!")
        @user.name = 'dbussink-the-second'
        @return = @first_comment.save
      end

      it 'should succesfully save the object' do
        @return.should be_true
      end

      it 'should still have a dirty user object' do
        @user.should be_dirty
      end

      it 'should not have persisted the changes' do
        @user.attributes.should_not == @model.get(*@user.key).attributes
      end

    end

  end

  it 'should respond to #destroy' do
    @user.should respond_to(:destroy)
  end

  describe '#destroy' do

    describe 'on a single object' do

      before do
        @resource = @model.create(:name => "hacker", :age => 20)
        @return = @resource.destroy
      end

      it 'should successfully remove a resource' do
        @return.should be_true
      end

      it 'should freeze the destoyed resource' do
        pending "it freezes resources when destroying them" do
          @resource.should be_frozen
        end
      end

      it 'should not be able to remove an already removed resource' do
        @resource.destroy.should be_false
      end

      it 'should remove object from persitent storage' do
        @model.get(*@resource.key).should be_nil
      end

    end

    describe 'with has relationship resources' do

      it 'should raise an exception'

    end

  end

  [ :==, :eql?, :=== ].each do |method|

    it { @user.should respond_to(method) }

    describe "##{method}" do

      it "should be true when they are the same objects" do
        @user.send(method, @user).should be_true
      end

      it "should be true when all the attributes are the same" do
        @user.send(method, @model.get(@user.key)).should be_true
      end

      it "should be true when all the attributes are the same even if one has not been persisted" do
        @model.get(@user.key).send(method, @model.new(:name => "dbussink", :age => 25, :description => "Test")).should be_true
      end

      it "should not be true when the attributes differ even if the keys are the same" do
        @user.age = 20
        @user.send(method, @model.get(@user.key)).should be_false
      end

      with_alternate_adapter do
        it "should be true when they are instances from different repositories, but the keys and attributes are the same" do
          @other = repository(:alternate) { @model.create(:name => "dbussink", :age => 25, :description => "Test") }
          @user.send(method, @other).should be_true
        end
      end

    end

  end

  it { @user.should respond_to(:hash) }

  describe '#hash' do

    describe 'on two equal unsaved objects' do

      before do
        @user1 = User.new(:name => 'dbussink', :age => 50)
        @user2 = User.new(:name => 'dbussink', :age => 50)
      end

      it { @user1.hash.should eql(@user2.hash) }

    end

    describe 'on two equal objects with a different object id' do

      before { @user2 = User.get("dbussink") }

      it { @user.object_id.should_not eql(@user2.object_id) }

      it { @user.hash.should eql(@user2.hash) }

    end


    describe 'on two different objects of the same type' do

      before { @user2 = User.create(:name => "dkubb", :age => 25) }

      it { @user.hash.should_not eql(@user2.hash) }

    end

    describe 'on two different types with the same key' do

      before { @user2 = Clone.create(:name => "dbussink", :age => 25) }

      it { @user.hash.should_not eql(@user2.hash) }

    end

  end

  it { @user.should respond_to(:inspect) }

  describe '#inspect' do

    before do
      @user = @model.get(@user.key)
      @inspected = @user.inspect
    end

    it { @inspected.should match(/^#<User/) }

    it { @inspected.should match(/name="dbussink"/) }

    it { @inspected.should match(/age=25/) }

    it { @inspected.should match(/description=<not loaded>/) }

  end

  it { @user.should respond_to(:repository) }

  it { @user.should respond_to(:key) }

  describe '#key' do

    before do
      @key = @user.key
      @user.name = 'dkubb'
    end

    it { @key.should be_kind_of(Array) }

    it 'should always return the key value persisted in the back end' do
      @key.first.should eql("dbussink")
    end

    it { @user.key.should eql(@key) }

  end

  it { @user.should respond_to(:reload) }

  describe '#reload' do

    before do
      @user.name = 'dkubb'
      @user.reload
    end

    it { @user.name.should eql("dbussink")}

    it 'should also reload previously loaded attributes' do
      skip_class = DataMapper::Associations::ManyToOne::Proxy
      pending_if "TODO: update #{skip_class}#save to actually save the object", @user.kind_of?(skip_class) do
        @user.attribute_loaded?(:description).should be_true
      end
    end

  end

  it { @user.should respond_to(:attributes) }

  describe '#attributes' do

    it { @user.attributes.should == {:name => 'dbussink', :description => "Test", :age => 25} }

  end

  it { @user.should respond_to(:attributes=) }

  describe '#attributes' do

    before do
      @user.attributes = {:name => 'dkubb', :age => 30}
    end

    it { @user.name.should == "dkubb" }
    it { @user.age.should == 30 }

    it 'should raise an exception if an non-existent attribute is set' do
      lambda { @user.attributes = {:nonexistent => 'value'} }.should raise_error
    end

  end

  it { @user.should respond_to(:new_record?) }

  describe '#new_record?' do

    describe 'on an existing record' do

      it { @user.should_not be_new_record }

    end

    describe 'on a new record' do

      before { @user = User.new }

      it { @user.should be_new_record }

    end

  end

  it 'should respond to #dirty?'

  describe '#dirty' do

    describe 'on a non-dirty record' do

      it { @user.should_not be_dirty }

    end

    describe 'on a dirty record' do

      before { @user.age = 100 }

      it { @user.should be_dirty }

    end

    describe 'on a new record' do

      before { @user = User.new }

      it { @user.should be_dirty }

    end

  end

  it 'should respond to #attribute_dirty?'

  describe '#attribute_dirty' do

    describe 'on a non-dirty record' do

      it { @user.attribute_dirty?(:age).should be_false }

    end

    describe 'on a dirty record' do

      before { @user.age = 100 }

      it { @user.attribute_dirty?(:age).should be_true }

    end

    describe 'on a new record' do

      before { @user = User.new }

      it { @user.attribute_dirty?(:age).should be_true }

    end

  end

  describe 'invalid resources' do

    before do
      Object.send(:remove_const, :EmptyObject) if defined?(EmptyObject)
      class EmptyObject
        include DataMapper::Resource
      end

      Object.send(:remove_const, :KeylessObject) if defined?(KeylessObject)
      class KeylessObject
        include DataMapper::Resource
        property :name, String
      end
    end

    it 'should raise an error for a resource without attributes' do
      lambda { EmptyObject.new }.should raise_error
    end

    it 'should raise an error for a resource without a key' do
      lambda { KeylessObject.new }.should raise_error
    end

  end

end
