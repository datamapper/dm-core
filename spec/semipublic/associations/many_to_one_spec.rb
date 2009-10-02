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

    class ::Comment
      include DataMapper::Resource

      property :id, Serial

      belongs_to :user
    end

    @user_model    = User
    @comment_model = Comment
  end

  supported_by :all do
    before :all do
      comment = @comment_model.create(:user => User.create(:name => 'dbussink', :age => 25, :description => 'Test'))

      @user = @comment_model.get(*comment.key).user
    end

    it_should_behave_like 'A semipublic Resource'
  end
end
