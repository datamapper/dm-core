require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'spec_helper'))

describe 'Many to One Associations' do
  before :all do
    class ::User
      include DataMapper::Resource

      property :name,        String, :key => true
      property :age,         Integer
      property :description, Text

      has n, :comments
    end

    # This is a special class that needs to be an exact copy of User
    class ::Clone
      include DataMapper::Resource

      property :name,        String, :key => true
      property :age,         Integer
      property :description, Text
    end

    class ::Comment
      include DataMapper::Resource

      property :id,   Serial
      property :body, Text

      belongs_to :user
    end

    class ::Default
      include DataMapper::Resource

      property :name, String, :key => true, :default => 'a default value'
    end

    @user_model    = User
    @comment_model = Comment
  end

  supported_by :all do
    before :all do
      comment = @comment_model.create(:body => 'Cool spec', :user => User.create(:name => 'dbussink', :age => 25, :description => 'Test'))

      comment = @comment_model.get(*comment.key)
      @user   = comment.user
    end

    it_should_behave_like 'A semipublic Resource'
  end
end
