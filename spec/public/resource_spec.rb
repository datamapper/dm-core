require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

describe DataMapper::Resource do
  before :all do
    module ::Blog
      class User
        include DataMapper::Resource

        property :name,        String, :key => true
        property :age,         Integer
        property :summary,     Text
        property :description, Text
        property :admin,       Boolean, :accessor => :private

        belongs_to :parent, self, :required => false
        has n, :children, self, :inverse => :parent

        belongs_to :referrer, self, :required => false
        has n, :comments

        # FIXME: figure out a different approach than stubbing things out
        def comment=(*)
          # do nothing with comment
        end
      end

      class Author < User; end

      class Comment
        include DataMapper::Resource

        property :id,   Serial
        property :body, Text

        belongs_to :user
      end

      class Article
        include DataMapper::Resource

        property :id,   Serial
        property :body, Text

        has n, :paragraphs
      end

      class Paragraph
        include DataMapper::Resource

        property :id,   Serial
        property :text, String

        belongs_to :article
      end
    end

    class ::Default
      include DataMapper::Resource

      property :name, String, :key => true, :default => 'a default value'
    end

    @user_model      = Blog::User
    @author_model    = Blog::Author
    @comment_model   = Blog::Comment
    @article_model   = Blog::Article
    @paragraph_model = Blog::Paragraph
  end

  supported_by :all do
    before :all do
      user = @user_model.create(:name => 'dbussink', :age => 25, :description => 'Test')

      @user = @user_model.get(*user.key)
    end

    it_should_behave_like 'A public Resource'
    it_should_behave_like 'A Resource supporting Strategic Eager Loading'
  end
end
