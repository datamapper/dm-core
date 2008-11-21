share_examples_for 'A public Resource' do
  before do
    %w[ @model @user @child_model ].each do |ivar|
      raise "+#{ivar}+ should be defined in before block" unless instance_variable_get(ivar)
    end
  end

  it { @user.should respond_to(:<=>) }

  describe '#<=>' do
    describe 'when the default order properties are equal with another resource' do
      before do
        @other = User.new(:name => 'dbussink')
        @return = @user <=> @other
      end

      it 'should return 0' do
        @return.should == 0
      end
    end

    describe 'when the default order property values are sorted before another resource' do
      before do
        @other = User.new(:name => 'c')
        @return = @user <=> @other
      end

      it 'should return 1' do
        @return.should == 1
      end
    end

    describe 'when the default order property values are sorted after another resource' do
      before do
        @other = User.new(:name => 'e')
        @return = @user <=> @other
      end

      it 'should return -1' do
        @return.should == -1
      end
    end

    describe 'when comparing an unrelated type of Object' do
      it 'should raise an exception' do
        lambda { @user <=> Comment.new }.should raise_error(ArgumentError, 'Cannot compare a Comment instance with a User instance')
      end
    end
  end

  it { @user.should respond_to(:attribute_get) }

  describe '#attribute_get' do

    it { @user.attribute_get(:name).should == 'dbussink' }

  end

  it { @user.should respond_to(:attribute_set) }

  describe '#attribute_set' do

    before { @user.attribute_set(:name, 'dkubb') }

    it { @user.name.should == 'dkubb' }

  end

  it { @user.should respond_to(:save) }

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
        @user.attributes.should == @model.get(*@user.key).attributes
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
        @first_comment    = @user.comments.new(:body => "DM is great!")
        @second_comment   = @child_model.new(:user => @user, :body => "is it really?")
        @return           = @user.save
      end

      it 'should save resource' do
        @return.should be_true
      end

      it 'should save the first resource created through new' do
        @first_comment.new_record?.should be_false
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
        pending "it should raise an exception when a parent is not persisted" do
          lambda { @first_comment.save }.should raise_error
        end
      end

    end

    describe 'with a dirty parent object' do

      before do
        @first_comment = @user.comments.new(:body => "DM is great!")
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

    describe 'with a new object and new relations' do

      before do
        @article = Article.new(:body => "Main")
        @paragraph = @article.paragraphs.new(:text => "Content")
        @article.save
      end

      it { @article.should_not be_dirty }
      it { @paragraph.should_not be_dirty }

      it 'should set the related object' do
        pending 'saving a new object should set the child key' do
          @paragraph.article.should == @article
        end
      end

      it 'should set the foreign key properly' do
        pending 'saving a new object should set the child key' do
          @paragraph.article_id.should == @article.id
        end
      end

    end

  end

  it { @user.should respond_to(:destroy) }

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
      @user.attribute_loaded?(:description).should be_true
    end

  end

  it { @user.should respond_to(:attributes) }

  describe '#attributes' do

    it { @user.attributes.should == {:name => 'dbussink', :description => "Test", :age => 25} }

  end

  it { @user.should respond_to(:attributes=) }

  describe '#attributes=' do

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
