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
        pending "TODO: update #{skip_class}#save to actually save the object" if @user.kind_of?(skip_class)
        @user.attributes.should == @model.get(*@user.key).attributes
      end
    end

    describe 'on a dirty invalid object' do

      before do
        @user.name = nil
      end

      it 'should not save an invalid resource' do
        pending "it raises an exception when trying to save a non serial nil key"
        @user.save.should be_false
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
        pending "TODO: update #{skip_class}#save to actually save the object" if @user.kind_of?(skip_class)
        @first_comment.new_record?.should be_false
      end

      it 'should save the correct foreign key for the first resource' do
        @first_comment.user.should eql(@user)
      end

      it 'should save the second resource created through the constructor' do
        pending "Changing a belongs_to parent should add the object to the correct association"
        @second_comment.new_record?.should be_false
      end

      it 'should save the correct foreign key for the second resource' do
        @second_comment.user.should eql(@user)
      end

      it 'should create 2 extra resources in persistent storage' do
        pending "Changing a belongs_to parent should add the object to the correct association"
        @user.comments.size.should == @initial_comments + 2
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
        pending "TODO: update #{skip_class}#save to actually save the object" if @user.kind_of?(skip_class)
        @first_comment.should_not be_dirty
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
        pending "it should raise an exception when a parent is not persisted"
        lambda { @first_comment.save }.should raise_error
      end

    end

    describe 'with a dirty parent object' do

      before do
        @first_comment      = @user.comments.new(:body => "DM is great!")
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
        pending "it freezes resources when destroying them"
        @resource.should be_frozen
      end

      it 'should not be able to remove an already removed resource' do
        @resource.destroy.should be_false
      end

      it 'should remove object from persitent storage' do
        @model.get(*@resource.key).should be_nil
      end

    end

    describe 'with a belongs_to relation resource' do

      it 'should be destroyed'

    end

    describe 'with has relationship resources' do

      it 'should raise an exception'

    end

  end
end
