share_examples_for 'A public Resource' do
  before do
    %w[ @model @user @child_model ].each do |ivar|
      raise "+#{ivar}+ should be defined in before block" unless instance_variable_get(ivar)
    end
  end

  [ :==, :=== ].each do |method|
    it { @user.should respond_to(method) }

    describe "##{method}" do
      describe 'when comparing to the same object' do
        before do
          @other  = @user
          @return = @user.send(method, @other)
        end

        it 'should return true' do
          @return.should be_true
        end
      end

      describe 'when comparing to an object that does not respond to model' do
        before do
          @other  = Object.new
          @return = @user.send(method, @other)
        end

        it 'should return false' do
          @return.should be_false
        end
      end

      describe 'when comparing to a resource with the same properties, but the model is a subclass' do
        before do
          @other  = Author.new(@user.attributes)
          @return = @user.send(method, @other)
        end

        it 'should return true' do
          @return.should be_true
        end
      end

      describe 'when comparing to a resource with the same repository, key and neither self or the other resource is dirty' do
        before do
          @other  = @model.get(*@user.key)
          @return = @user.send(method, @other)
        end

        it 'should return true' do
          @return.should be_true
        end
      end

      describe 'when comparing to a resource with the same repository, key but either self or the other resource is dirty' do
        before do
          @user.age = 20
          @other  = @model.get(*@user.key)
          @return = @user.send(method, @other)
        end

        it 'should return false' do
          @return.should be_false
        end
      end

      describe 'when comparing to a resource with the same properties' do
        before do
          @other  = @model.new(@user.attributes)
          @return = @user.send(method, @other)
        end

        it 'should return true' do
          @return.should be_true
        end
      end

      with_alternate_adapter do
        describe 'when comparing to a resource with a different repository, but the same properties' do
          before do
            @other = @alternate_repository.scope { @model.create(@user.attributes) }
            @return = @user.send(method, @other)
          end

          it 'should return true' do
            @return.should be_true
          end
        end
      end
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

  it { @user.should respond_to(:attributes) }

  describe '#attributes' do

    it { @user.attributes.should == {:name => 'dbussink', :description => "Test", :age => 25, :referrer_name => nil} }

  end

  it { @user.should respond_to(:attributes=) }

  describe '#attributes=' do
    describe 'when a public mutator is specified' do
      before do
        @user.attributes = {:name => 'dkubb'}
      end

      it 'should set the value' do
        @user.name.should eql('dkubb')
      end
    end

    describe 'when a non-public mutator is specified' do
      it 'should raise an exception' do
        lambda {
          @user.attributes = { :admin => true }
        }.should raise_error(ArgumentError, 'The property \'admin\' is not accessible in User')
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

  it { @user.should respond_to(:eql?) }

  describe '#eql?' do
    describe 'when comparing to the same object' do
      before do
        @other  = @user
        @return = @user.eql?(@other)
      end

      it 'should return true' do
        @return.should be_true
      end
    end

    describe 'when comparing to an object that does not respond to model' do
      before do
        @other  = Object.new
        @return = @user.eql?(@other)
      end

      it 'should return false' do
        @return.should be_false
      end
    end

    describe 'when comparing to a resource with the same properties, but the model is a subclass' do
      before do
        @other  = Author.new(@user.attributes)
        @return = @user.eql?(@other)
      end

      it 'should return false' do
        @return.should be_false
      end
    end

    describe 'when comparing to a resource with a different key' do
      before do
        @other     = @model.create(:name => 'dkubb', :age => 33)
        @return    = @user.eql?(@other)
      end

      it 'should return false' do
        @return.should be_false
      end
    end

    describe 'when comparing to a resource with the same repository, key and neither self or the other resource is dirty' do
      before do
        @other  = @model.get(*@user.key)
        @return = @user.eql?(@other)
      end

      it 'should return true' do
        @return.should be_true
      end
    end

    describe 'when comparing to a resource with the same repository, key but either self or the other resource is dirty' do
      before do
        @user.age = 20
        @other  = @model.get(*@user.key)
        @return = @user.eql?(@other)
      end

      it 'should return false' do
        @return.should be_false
      end
    end

    describe 'when comparing to a resource with the same properties' do
      before do
        @other  = @model.new(@user.attributes)
        @return = @user.eql?(@other)
      end

      it 'should return true' do
        @return.should be_true
      end
    end

    with_alternate_adapter do
      describe 'when comparing to a resource with a different repository, but the same properties' do
        before do
          @other = @alternate_repository.scope { @model.create(@user.attributes) }
          @return = @user.eql?(@other)
        end

        it 'should return true' do
          @return.should be_true
        end
      end
    end
  end

  it { @user.should respond_to(:inspect) }

  describe '#inspect' do

    before do
      @user = @model.get(*@user.key)
      @inspected = @user.inspect
    end

    it { @inspected.should match(/^#<User/) }

    it { @inspected.should match(/name="dbussink"/) }

    it { @inspected.should match(/age=25/) }

    it { @inspected.should match(/description=<not loaded>/) }

  end

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

  it { @user.should respond_to(:new?) }

  describe '#new?' do

    describe 'on an existing record' do

      it { @user.should_not be_new }

    end

    describe 'on a new record' do

      before { @user = User.new }

      it { @user.should be_new }

    end

  end

  it { @user.should respond_to(:reload) }

  describe '#reload' do

    before do
      @user.name = 'dkubb'
      @user.description = 'test'
      @user.reload
    end

    it { @user.name.should eql('dbussink') }

    it 'should also reload previously loaded attributes' do
      @user.attribute_loaded?(:description).should be_true
    end

  end

  it { @user.should respond_to(:save) }

  describe '#save' do

    describe 'on a new, not dirty object' do

      before do
        @user = @model.new
        @return = @user.save
      end

      it 'should return false' do
        @return.should be_false
      end

    end

    describe 'on a not new, not dirty object' do

      it 'should return true even when resource is not dirty' do
        @user.save.should be_true
      end

    end

    describe 'on a not new, dirty object' do

      before do
        @user.age = 26
        @return = @user.save
      end

      it 'should save a resource succesfully when dirty' do
        @return.should be_true
      end

      it 'should actually store the changes to persistent storage' do
        @user.attributes.should == @user.reload.attributes
      end
    end

    describe 'on a dirty invalid object' do
      before do
        @user.name = nil
      end

      it 'should not save an invalid resource' do
        @user.save.should be_false
      end
    end

    describe 'with new resources in a has relationship' do

      before do
        pending_if 'TODO: fix for one to one association', (!@user.respond_to?(:comments)) do
          @initial_comments = @user.comments.size
          @first_comment    = @user.comments.new(:body => "DM is great!")
          @second_comment   = @child_model.new(:user => @user, :body => "is it really?")
          @return           = @user.save
        end
      end

      it 'should save resource' do
        @return.should be_true
      end

      it 'should save the first resource created through new' do
        @first_comment.new?.should be_false
      end

      it 'should save the correct foreign key for the first resource' do
        @first_comment.user.should eql(@user)
      end

      it 'should save the second resource created through the constructor' do
        pending "Changing a belongs_to parent should add the object to the correct association" do
          @second_comment.new?.should be_false
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
        pending_if 'TODO: fix for one to one association', (!@user.respond_to?(:comments)) do
          @initial_comments = @user.comments.size
          @first_comment    = @user.comments.create(:body => "DM is great!")
          @second_comment   = @child_model.create(:user => @user, :body => "is it really?")

          @first_comment.body  = "It still has rough edges"
          @second_comment.body = "But these cool specs help fixing that"
          @second_comment.user = @model.create(:name => 'dkubb')
          @return              = @user.save
        end
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
        pending_if 'TODO: fix for one to one association', (!@user.respond_to?(:comments)) do
          @first_comment = @user.comments.new(:body => "DM is great!")
          @user.name = 'dbussink-the-second'
          @return = @first_comment.save
        end
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
        pending_if 'TODO: fix for one to one association', (!@article.respond_to?(:paragraphs)) do
          @paragraph = @article.paragraphs.new(:text => "Content")
          @article.save
        end
      end

      it { @article.should_not be_dirty }
      it { @paragraph.should_not be_dirty }

      it 'should set the related object' do
        @paragraph.article.should == @article
      end

      it 'should set the foreign key properly' do
        @paragraph.article_id.should == @article.id
      end
    end

    describe 'with a dirty object with a changed key' do

      before do
        @user.name = 'dkubb'
        @return = @user.save
      end

      it 'should save a resource succesfully when dirty' do
        @return.should be_true
      end

      it 'should actually store the changes to persistent storage' do
        @user.attributes.should == @user.reload.attributes
      end

      it 'should update the identity map' do
        @user.repository.identity_map(@model).key?(%w[ dkubb ])
      end

    end

  end

  it { @user.should respond_to(:saved?) }

  describe '#saved?' do

    describe 'on an existing record' do

      it { @user.should be_saved }

    end

    describe 'on a new record' do

      before { @user = User.new }

      it { @user.should_not be_saved }

    end

  end

  it { @user.should respond_to(:update) }

  describe '#update' do
    describe 'with no arguments' do
      before do
        @return = @user.update
      end

      it 'should return true' do
        @return.should be_true
      end
    end

    describe 'with attributes' do
      before do
        @attributes = { :description => 'Changed' }
        @return = @user.update(@attributes)
      end

      it 'should return true' do
        @return.should be_true
      end

      it 'should update attributes of Resource' do
        @attributes.each { |k,v| @user.send(k).should == v }
      end

      it 'should persist the changes' do
        resource = @model.get(*@user.key)
        @attributes.each { |k,v| resource.send(k).should == v }
      end
    end

    describe 'with attributes where one is a parent association' do
      before do
        @attributes = { :referrer => @model.create(:name => 'dkubb', :age => 33) }
        @return = @user.update(@attributes)
      end

      it 'should return true' do
        @return.should be_true
      end

      it 'should update attributes of Resource' do
        @attributes.each { |k,v| @user.send(k).should == v }
      end

      it 'should persist the changes' do
        resource = @model.get(*@user.key)
        @attributes.each { |k,v| resource.send(k).should == v }
      end
    end

    describe 'with attributes where a value is nil for a property that does not allow nil' do
      before do
        @return = @user.update(:name => nil)
      end

      it 'should return false' do
        @return.should be_false
      end

      it 'should not persist the changes' do
        @user.reload.name.should_not be_nil
      end
    end
  end

  describe 'invalid resources' do

    before do
      class ::EmptyObject
        include DataMapper::Resource
      end

      class ::KeylessObject
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
