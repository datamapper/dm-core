require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'spec_helper'))

describe 'One to One Associations' do
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
        belongs_to :comment

        # TODO: remove this after Relationship#inverse can dynamically
        # create an inverse relationship when no perfect match can be found
        has n, :referree, self, :child_key => [ :referrer_name ]
      end

      class Author < User; end

      class Comment
        include DataMapper::Resource

        property :id,   Serial
        property :body, Text

        has 1, :user
      end

      class Article
        include DataMapper::Resource

        property :id,   Serial
        property :body, Text

        has 1, :paragraph
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
      comment = @comment_model.create(:body => 'Cool spec')
      user    = @user_model.create(:name => 'dbussink', :age => 25, :description => 'Test', :comment => comment)

      @comment = @comment_model.get(*comment.key)
      @user    = @comment.user
    end

    it_should_behave_like 'A public Resource'
    it_should_behave_like 'A Resource supporting Strategic Eager Loading'
  end
end

describe 'One to One Through Associations' do
  before :all do
    module ::Blog
      class Referral
        include DataMapper::Resource

        property :referrer_name, String, :key => true
        property :referree_name, String, :key => true

        belongs_to :referrer, 'User', :child_key => [ :referrer_name ]
        belongs_to :referree, 'User', :child_key => [ :referree_name ]
      end

      class User
        include DataMapper::Resource

        property :name,        String, :key => true
        property :age,         Integer
        property :summary,     Text
        property :description, Text
        property :admin,       Boolean, :accessor => :private

        belongs_to :parent, self, :required => false
        has n, :children, self, :inverse => :parent

        has 1, :referral_from, Referral, :child_key => [ :referree_name ]
        has 1, :referral_to,   Referral, :child_key => [ :referrer_name ]

        has 1, :referrer, self, :through => :referral_from
        has 1, :referree, self, :through => :referral_to
        has 1, :comment,        :through => Resource
      end

      class Author < User; end

      class Comment
        include DataMapper::Resource

        property :id,   Serial
        property :body, Text

        has 1, :user, :through => Resource
      end

      class Article
        include DataMapper::Resource

        property :id,   Serial
        property :body, Text

        has 1, :paragraph, :through => Resource
      end

      class Paragraph
        include DataMapper::Resource

        property :id,   Serial
        property :text, String

        has 1, :article, :through => Resource
      end
    end

    class ::Default
      include DataMapper::Resource

      property :name, String, :key => true, :default => 'a default value'
    end

    @referral_model  = Blog::Referral
    @user_model      = Blog::User
    @author_model    = Blog::Author
    @comment_model   = Blog::Comment
    @article_model   = Blog::Article
    @paragraph_model = Blog::Paragraph
  end

  supported_by :all do
    before :all do
      comment = @comment_model.create(:body => 'Cool spec')
      user    = @user_model.create(:name => 'dbussink', :age => 25, :description => 'Test', :comment => comment)

      @comment = @comment_model.get(*comment.key)
      @user    = @comment.user
    end

    it_should_behave_like 'A public Resource'

    # TODO: make this pass
    #it_should_behave_like 'A Resource supporting Strategic Eager Loading'
  end
end
