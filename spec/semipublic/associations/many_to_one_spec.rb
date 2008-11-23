require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'spec_helper'))

describe 'Many to One Associations' do
  before do
    class User
      include DataMapper::Resource

      property :name,        String, :key => true
      property :age,         Integer
      property :description, Text

      has n, :comments
    end

    # This is a special class that needs to be an exact copy of User
    class Clone
      include DataMapper::Resource

      property :name,        String, :key => true
      property :age,         Integer
      property :description, Text
    end

    class Comment
      include DataMapper::Resource

      property :id,   Serial
      property :body, Text

      belongs_to :user
    end

    class Default
      include DataMapper::Resource

      property :name, String, :key => true, :default => 'a default value'
    end
  end

  supported_by :all do
    before do
      comment = Comment.create(:body => 'Cool spec', :user => User.create(:name => 'dbussink', :age => 25, :description => 'Test'))
      @user   = comment.user
      @model  = User
    end

    it_should_behave_like 'A semipublic Resource'
  end
end
