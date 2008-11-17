require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

describe DataMapper::Resource do

  before do
    Object.send(:remove_const, :User) if defined?(User)
    class User
      include DataMapper::Resource

      property :name, String, :key => true
      property :age,  Integer
      property :description, Text, :lazy => true

      has n, :comments
    end

    # This is a special class that needs to be an exact copy of User
    Object.send(:remove_const, :Clone) if defined?(Clone)
    class Clone
      include DataMapper::Resource

      property :name, String, :key => true
      property :age,  Integer
    end

    Object.send(:remove_const, :Article) if defined?(Article)
    class Article
      include DataMapper::Resource

      property :id,   String
      property :body, Text
    end

    Object.send(:remove_const, :Comment) if defined?(Comment)
    class Comment
      include DataMapper::Resource

      property :id,   Serial
      property :body, Text

      belongs_to :user
    end

    Object.send(:remove_const, :Authorship) if defined?(Authorship)
    class Authorship
      include DataMapper::Resource

      property :user_id,    Integer, :key => true
      property :article_id, Integer, :key => true
    end
  end

  supported_by :all do
    before do
      @model       = User
      @child_model = Comment
      @user        = @model.create(:name => 'dbussink', :age => 25, :description => "Test")
    end

    describe "#repository" do

      before(:each) do
        Object.send(:remove_const, :Statistic) if defined?(Statistic)
        class Statistic
          include DataMapper::Resource

          def self.default_repository_name ; :alternate ; end

          property :id,    Serial
          property :name,  String
          property :value, Integer
        end
      end

      with_alternate_adapter do
        it "should return the default adapter when nothing is specified" do
          User.create(:name => "carl").repository.should == repository(:default)
          User.new.repository.should                     == repository(:default)
          User.get("carl").repository.should             == repository(:default)
        end

        it "should return the default repository for the model" do
          statistic = Statistic.create(:name => "visits", :value => 2)
          statistic.repository.should        == repository(:alternate)
          Statistic.new.repository.should    == repository(:alternate)
          Statistic.get(1).repository.should == repository(:alternate)
        end

        it "should return the repository defined by the current context" do
          repository(:alternate) do
            User.new.repository.should                     == repository(:alternate)
            User.create(:name => "carl").repository.should == repository(:alternate)
            User.get("carl").repository.should             == repository(:alternate)
          end

          repository(:alternate) { User.get("carl") }.repository.should == repository(:alternate)
        end
      end

    end

    describe "#id" do

      it "should return the value of the id property if there is one" do
        Comment.create(:body => "Hello").id.should == 1
      end

      it "should return the value of the key if it is a single column key" do
        User.create(:name => "carl").id.should == "carl"
      end

      it "should return nil if the key is a multi column key" do
        Authorship.create(:user_id => 1, :article_id => 1).id.should be_nil
      end

    end

    describe "#readonly" do

      it "should return false when the resource can be written to" do
        User.create(:name => "carl").should_not be_readonly
      end

      it "should be able to switch a resource to read only" do
        user = User.create(:name => "carl")
        user.readonly!
        user.should be_readonly
      end
    end

    it_should_behave_like 'A Resource'

  end

end
