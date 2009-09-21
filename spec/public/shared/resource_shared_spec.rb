share_examples_for 'A public Resource' do
  before :all do
    @no_join = defined?(DataMapper::Adapters::InMemoryAdapter) && @adapter.kind_of?(DataMapper::Adapters::InMemoryAdapter) ||
               defined?(DataMapper::Adapters::YamlAdapter)     && @adapter.kind_of?(DataMapper::Adapters::YamlAdapter)

    relationship        = @user_model.relationships[:referrer]
    @one_to_one_through = relationship.kind_of?(DataMapper::Associations::OneToOne::Relationship) && relationship.respond_to?(:through)

    @skip = @no_join && @one_to_one_through
  end

  before :all do
    unless @skip
      %w[ @user_model @user @comment_model ].each do |ivar|
        raise "+#{ivar}+ should be defined in before block" unless instance_variable_get(ivar)
      end
    end
  end

  before do
    pending if @skip
  end

  [ :==, :=== ].each do |method|
    it { @user.should respond_to(method) }

    describe "##{method}" do
      describe 'when comparing to the same object' do
        before :all do
          @other  = @user
          @return = @user.send(method, @other)
        end

        it 'should return true' do
          @return.should be_true
        end
      end

      describe 'when comparing to an object that does not respond to model' do
        before :all do
          @other  = Object.new
          @return = @user.send(method, @other)
        end

        it 'should return false' do
          @return.should be_false
        end
      end

      describe 'when comparing to a resource with the same properties, but the model is a subclass' do
        before :all do
          rescue_if 'TODO', @skip do
            @other  = @author_model.new(@user.attributes)
            @return = @user.send(method, @other)
          end
        end

        it 'should return true' do
          @return.should be_true
        end
      end

      describe 'when comparing to a resource with the same repository, key and neither self or the other resource is dirty' do
        before :all do
          rescue_if 'TODO', @skip do
            @other  = @user_model.get(*@user.key)
            @return = @user.send(method, @other)
          end
        end

        it 'should return true' do
          @return.should be_true
        end
      end

      describe 'when comparing to a resource with the same repository, key but either self or the other resource is dirty' do
        before :all do
          rescue_if 'TODO', @skip do
            @user.age = 20
            @other  = @user_model.get(*@user.key)
            @return = @user.send(method, @other)
          end
        end

        it 'should return false' do
          @return.should be_false
        end
      end

      describe 'when comparing to a resource with the same properties' do
        before :all do
          rescue_if 'TODO', @skip do
            @other  = @user_model.new(@user.attributes)
            @return = @user.send(method, @other)
          end
        end

        it 'should return true' do
          @return.should be_true
        end
      end

      with_alternate_adapter do
        describe 'when comparing to a resource with a different repository, but the same properties' do
          before :all do
            rescue_if 'TODO', @skip do
              @other = @alternate_repository.scope { @user_model.create(@user.attributes) }
              @return = @user.send(method, @other)
            end
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
      before :all do
        rescue_if 'TODO', @skip do
          @other = @user_model.new(:name => 'dbussink')
          @return = @user <=> @other
        end
      end

      it 'should return 0' do
        @return.should == 0
      end
    end

    describe 'when the default order property values are sorted before another resource' do
      before :all do
        rescue_if 'TODO', @skip do
          @other = @user_model.new(:name => 'c')
          @return = @user <=> @other
        end
      end

      it 'should return 1' do
        @return.should == 1
      end
    end

    describe 'when the default order property values are sorted after another resource' do
      before :all do
        rescue_if 'TODO', @skip do
          @other = @user_model.new(:name => 'e')
          @return = @user <=> @other
        end
      end

      it 'should return -1' do
        @return.should == -1
      end
    end

    describe 'when comparing an unrelated type of Object' do
      it 'should raise an exception' do
        lambda { @user <=> @comment_model.new }.should raise_error(ArgumentError, "Cannot compare a #{@comment_model} instance with a #{@user_model} instance")
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

    it 'should return the expected values' do
      @user.attributes.only(:name, :description, :age).should == { :name => 'dbussink', :description => 'Test', :age => 25 }
    end

  end

  it { @user.should respond_to(:attributes=) }

  describe '#attributes=' do
    describe 'when a public mutator is specified' do
      before :all do
        rescue_if 'TODO', @skip do
          @user.attributes = { :name => 'dkubb' }
        end
      end

      it 'should set the value' do
        @user.name.should eql('dkubb')
      end
    end

    describe 'when a non-public mutator is specified' do
      it 'should raise an exception' do
        lambda {
          @user.attributes = { :admin => true }
        }.should raise_error(ArgumentError, "The attribute \'admin\' is not accessible in #{@user_model}")
      end
    end
  end

  [ :destroy, :destroy! ].each do |method|
    it { @user.should respond_to(:destroy) }

    describe "##{method}" do
      describe 'on a single object' do
        before :all do
          @resource = @user_model.create(:name => 'hacker', :age => 20, :comment => @comment)

          @return = @resource.send(method)
        end

        it 'should successfully remove a resource' do
          @return.should be_true
        end

        it 'should freeze the destroyed resource' do
          @resource.should be_frozen
        end

        it "should return true when calling #{method} on a destroyed resource" do
          @resource.send(method).should be_true
        end

        it 'should remove object from persistent storage' do
          @user_model.get(*@resource.key).should be_nil
        end
      end

      describe 'with has relationship resources' do
        it 'should raise an exception'
      end
    end
  end

  it { @user.should respond_to(:eql?) }

  describe '#eql?' do
    describe 'when comparing to the same object' do
      before :all do
        @other  = @user
        @return = @user.eql?(@other)
      end

      it 'should return true' do
        @return.should be_true
      end
    end

    describe 'when comparing to an object that does not respond to model' do
      before :all do
        @other  = Object.new
        @return = @user.eql?(@other)
      end

      it 'should return false' do
        @return.should be_false
      end
    end

    describe 'when comparing to a resource with the same properties, but the model is a subclass' do
      before :all do
        rescue_if 'TODO', @skip do
          @other  = @author_model.new(@user.attributes)
          @return = @user.eql?(@other)
        end
      end

      it 'should return false' do
        @return.should be_false
      end
    end

    describe 'when comparing to a resource with a different key' do
      before :all do
        @other     = @user_model.create(:name => 'dkubb', :age => 33, :comment => @comment)
        @return    = @user.eql?(@other)
      end

      it 'should return false' do
        @return.should be_false
      end
    end

    describe 'when comparing to a resource with the same repository, key and neither self or the other resource is dirty' do
      before :all do
        rescue_if 'TODO', @skip do
          @other  = @user_model.get(*@user.key)
          @return = @user.eql?(@other)
        end
      end

      it 'should return true' do
        @return.should be_true
      end
    end

    describe 'when comparing to a resource with the same repository, key but either self or the other resource is dirty' do
      before :all do
        rescue_if 'TODO', @skip do
          @user.age = 20
          @other  = @user_model.get(*@user.key)
          @return = @user.eql?(@other)
        end
      end

      it 'should return false' do
        @return.should be_false
      end
    end

    describe 'when comparing to a resource with the same properties' do
      before :all do
        rescue_if 'TODO', @skip do
          @other  = @user_model.new(@user.attributes)
          @return = @user.eql?(@other)
        end
      end

      it 'should return true' do
        @return.should be_true
      end
    end

    with_alternate_adapter do
      describe 'when comparing to a resource with a different repository, but the same properties' do
        before :all do
          rescue_if 'TODO', @skip do
            @other = @alternate_repository.scope { @user_model.create(@user.attributes) }
            @return = @user.eql?(@other)
          end
        end

        it 'should return true' do
          @return.should be_true
        end
      end
    end
  end

  it { @user.should respond_to(:inspect) }

  describe '#inspect' do

    before :all do
      rescue_if 'TODO', @skip do
        @user = @user_model.get(*@user.key)
        @inspected = @user.inspect
      end
    end

    it { @inspected.should match(/^#<#{@user_model}/) }

    it { @inspected.should match(/name="dbussink"/) }

    it { @inspected.should match(/age=25/) }

    it { @inspected.should match(/description=<not loaded>/) }

  end

  it { @user.should respond_to(:key) }

  describe '#key' do

    before :all do
      rescue_if 'TODO', @skip do
        @key = @user.key
        @user.name = 'dkubb'
      end
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

      before { @user = @user_model.new }

      it { @user.should be_new }

    end

  end

  it { @user.should respond_to(:reload) }

  describe '#reload' do

    describe 'for a single object' do

      before :all do
        rescue_if 'TODO', @skip do
          @user.name = 'dkubb'
          @user.description = 'test'
          @user.reload
        end
      end

      it { @user.name.should eql('dbussink') }

      it 'should also reload previously loaded attributes' do
        @user.attribute_loaded?(:description).should be_true
      end
    end

    describe 'for when the object is changed outside another object' do

      before :all do
        rescue_if 'TODO', @skip do
          @user2 = @user.dup
          @user2.description = 'Changed'
          @user2.save
          @user.reload
        end
      end

      it 'should reload the object from the data store' do
        @user.description.should eql('Changed')
      end

    end

  end

  it { @user.should respond_to(:save) }

  describe '#save' do

    describe 'on a new, not dirty object' do

      before :all do
        @user = @user_model.new
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

      before :all do
        rescue_if 'TODO', @skip do
          @user.age = 26
          @return = @user.save
        end
      end

      it 'should save a resource succesfully when dirty' do
        @return.should be_true
      end

      it 'should actually store the changes to persistent storage' do
        @user.attributes.should == @user.reload.attributes
      end
    end

    describe 'on a dirty invalid object' do
      before :all do
        rescue_if 'TODO', @skip do
          @user.name = nil
        end
      end

      it 'should not save an invalid resource' do
        @user.save.should be_false
      end
    end

    describe 'with new resources in a has relationship' do
      before do
        rescue_if 'TODO: fix for one to one association', !@user.respond_to?(:comments) do
          @initial_comments = @user.comments.size
          @first_comment    = @user.comments.new(:body => "DM is great!")
          @second_comment   = @comment_model.new(:user => @user, :body => "is it really?")
          @return           = @user.save
        end
      end

      it 'should save resource' do
        pending_if 'TODO', !@user.respond_to?(:comments) do
          @return.should be_true
        end
      end

      it 'should save the first resource created through new' do
        pending_if 'TODO', !@user.respond_to?(:comments) do
          @first_comment.new?.should be_false
        end
      end

      it 'should save the correct foreign key for the first resource' do
        pending_if 'TODO', !@user.respond_to?(:comments) do
          @first_comment.user.should eql(@user)
        end
      end

      it 'should save the second resource created through the constructor' do
        pending "Changing a belongs_to parent should add the object to the correct association" do
          @second_comment.new?.should be_false
        end
      end

      it 'should save the correct foreign key for the second resource' do
        pending_if 'TODO', !@user.respond_to?(:comments) do
          @second_comment.user.should eql(@user)
        end
      end

      it 'should create 2 extra resources in persistent storage' do
        pending "Changing a belongs_to parent should add the object to the correct association" do
          @user.comments.size.should == @initial_comments + 2
        end
      end

    end

    describe 'with dirty resources in a has relationship' do
      before :all do
        rescue_if 'TODO: fix for one to one association', !@user.respond_to?(:comments) do
          @initial_comments = @user.comments.size
          @first_comment    = @user.comments.create(:body => "DM is great!")
          @second_comment   = @comment_model.create(:user => @user, :body => "is it really?")

          @first_comment.body  = "It still has rough edges"
          @second_comment.body = "But these cool specs help fixing that"
          @second_comment.user = @user_model.create(:name => 'dkubb')
          @return              = @user.save
        end
      end

      it 'should save the dirty resources' do
        pending_if 'TODO', !@user.respond_to?(:comments) do
          @return.should be_true
        end
      end

      it 'should have saved the first child resource' do
        pending_if 'TODO', !@user.respond_to?(:comments) do
          @first_comment.should_not be_dirty
        end
      end

      it 'should not have saved the second child resource' do
        pending_if 'TODO', !@user.respond_to?(:comments) do
          @second_comment.should be_dirty
        end
      end

    end

    describe 'with a new dependency' do

      before :all do
        @first_comment      = @comment_model.new(:body => "DM is great!")
        @first_comment.user = @user_model.new(:name => 'dkubb')
      end

      it 'should not raise an exception when saving the resource' do
        pending do
          lambda { @first_comment.save.should be_false }.should_not raise_error
        end
      end

    end

    describe 'with a dirty dependency' do
      before :all do
        rescue_if 'TODO', @skip do
          @user.name = 'dbussink-the-second'

          @first_comment = @comment_model.new(:body => 'DM is great!')
          @first_comment.user = @user

          @return = @first_comment.save
        end
      end

      it 'should succesfully save the object' do
        @return.should be_true
      end

      it 'should not have a dirty dependency' do
        @user.should_not be_dirty
      end

      it 'should succesfully save the dependency' do
        @user.attributes.should == @user_model.get(*@user.key).attributes
      end

    end

    describe 'with a new object and new relations' do
      before :all do
        @article = @article_model.new(:body => "Main")
        rescue_if 'TODO: fix for one to one association', (!@article.respond_to?(:paragraphs)) do
          @paragraph = @article.paragraphs.new(:text => 'Content')

          @article.save
        end
      end

      it 'should not be dirty' do
        pending_if 'TODO', !@article.respond_to?(:paragraphs) do
          @article.should_not be_dirty
        end
      end

      it 'should not be dirty' do
        pending_if 'TODO', !@article.respond_to?(:paragraphs) do
          @paragraph.should_not be_dirty
        end
      end

      it 'should set the related object' do
        pending_if 'TODO', !@article.respond_to?(:paragraphs) do
          @paragraph.article.should == @article
        end
      end

      it 'should set the foreign key properly' do
        pending_if 'TODO', !@article.respond_to?(:paragraphs) do
          @paragraph.article_id.should == @article.id
        end
      end
    end

    describe 'with a dirty object with a changed key' do

      before :all do
        rescue_if 'TODO', @skip do
          @original_key = @user.key
          @user.name = 'dkubb'
          @return = @user.save
        end
      end

      it 'should save a resource succesfully when dirty' do
        @return.should be_true
      end

      it 'should actually store the changes to persistent storage' do
        @user.name.should == @user.reload.name
      end

      it 'should update the identity map' do
        @user.repository.identity_map(@user_model).should have_key(%w[ dkubb ])
      end

      it 'should remove the old entry from the identity map' do
        @user.repository.identity_map(@user_model).should_not have_key(@original_key)
      end

    end

    describe 'on a new object with unsaved parent and grandparent' do
      before :all do
        @grandparent = @user_model.new(:name => 'dkubb',       :comment => @comment)
        @parent      = @user_model.new(:name => 'ashleymoran', :comment => @comment, :referrer => @grandparent)
        @child       = @user_model.new(:name => 'mrship',      :comment => @comment, :referrer => @parent)

        @response = @child.save
      end

      it 'should return true' do
        @response.should be_true
      end

      it 'should save the child' do
        @child.should be_saved
      end

      it 'should save the parent' do
        @parent.should be_saved
      end

      it 'should save the grandparent' do
        @grandparent.should be_saved
      end

      it 'should relate the child to the parent' do
        pending_if 'TODO', @one_to_one_through do
          @child.model.get(*@child.key).referrer.should == @parent
        end
      end

      it 'should relate the parent to the grandparent' do
        pending_if 'TODO', @one_to_one_through do
          @parent.model.get(*@parent.key).referrer.should == @grandparent
        end
      end

      it 'should relate the grandparent to nothing' do
        pending_if 'TODO', @one_to_one_through do
          @grandparent.model.get(*@grandparent.key).referrer.should be_nil
        end
      end
    end

  end

  it { @user.should respond_to(:saved?) }

  describe '#saved?' do

    describe 'on an existing record' do

      it { @user.should be_saved }

    end

    describe 'on a new record' do

      before { @user = @user_model.new }

      it { @user.should_not be_saved }

    end

  end

  [ :update, :update! ].each do |method|
    it { @user.should respond_to(method) }

    describe "##{method}" do
      describe 'with no arguments' do
        before :all do
          rescue_if 'TODO', @skip do
            @return = @user.send(method)
          end
        end

        it 'should return true' do
          @return.should be_true
        end
      end

      describe 'with attributes' do
        before :all do
          rescue_if 'TODO', @skip do
            @attributes = { :description => 'Changed' }
            @return = @user.send(method, @attributes)
          end
        end

        it 'should return true' do
          @return.should be_true
        end

        it 'should update attributes of Resource' do
          @attributes.each { |key, value| @user.send(key).should == value }
        end

        it 'should persist the changes' do
          resource = @user_model.get(*@user.key)
          @attributes.each { |key, value| resource.send(key).should == value }
        end
      end

      describe 'with attributes where one is a parent association' do
        before :all do
          rescue_if 'Use table aliases to avoid ambiguous named in query', @one_to_one_through do
            @attributes = { :referrer => @user_model.create(:name => 'dkubb', :age => 33, :comment => @comment) }
            @return = @user.send(method, @attributes)
          end
        end

        it 'should return true' do
          pending_if 'TODO', @one_to_one_through do
            @return.should be_true
          end
        end

        it 'should update attributes of Resource' do
          pending_if 'TODO', @one_to_one_through do
            @attributes.each { |key, value| @user.send(key).should == value }
          end
        end

        it 'should persist the changes' do
          pending_if 'TODO', @one_to_one_through do
            resource = @user_model.get(*@user.key)
            @attributes.each { |key, value| resource.send(key).should == value }
          end
        end
      end

      describe 'with attributes where a value is nil for a property that does not allow nil' do
        before :all do
          rescue_if 'TODO', @skip do
            @return = @user.send(method, :name => nil)
          end
        end

        it 'should return false' do
          @return.should be_false
        end

        it 'should not persist the changes' do
          @user.reload.name.should_not be_nil
        end
      end

      describe 'on a dirty resource' do
        before :all do
          rescue_if 'TODO', @skip do
            @user.age = 99
          end
        end

        it 'should raise an exception' do
          lambda {
            @user.send(method, :admin => true)
          }.should raise_error(DataMapper::UpdateConflictError, "#{@user.model}##{method} cannot be called on a dirty resource")
        end
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

    after do
      # clean out invalid models so that global model cleanup
      # does not throw an exception when working with models
      # in an invalid state
      [ EmptyObject, KeylessObject ].each do |model|
        Object.send(:remove_const, model.name.to_sym)
        DataMapper::Model.descendants.delete(model)
      end
    end
  end

  describe 'lazy loading' do
    before :all do
      rescue_if 'TODO', @skip do
        @user.name    = 'dkubb'
        @user.age     = 33
        @user.summary = 'Programmer'

        # lazy load the description
        @user.description
      end
    end

    it 'should not overwrite dirty attribute' do
      @user.age.should == 33
    end

    it 'should not overwrite dirty lazy attribute' do
      @user.summary.should == 'Programmer'
    end

    it 'should not overwrite dirty key' do
      pending do
        @user.name.should == 'dkubb'
      end
    end
  end
end
