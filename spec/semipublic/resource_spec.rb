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

    it_should_behave_like 'A semipublic Resource'

  end

end
