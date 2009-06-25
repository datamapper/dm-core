require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

describe 'SEL', 'with different key types' do
  before :all do
    module ::Blog
      class Author
        include DataMapper::Resource

        property :id,   Serial
        property :name, String

        has n, :articles
      end

      class Article
        include DataMapper::Resource

        property :id,      Serial
        property :title,   String, :nullable => false

        property :author_id, String  # different type

        belongs_to :author
      end
    end

    @author_model  = Blog::Author
    @article_model = Blog::Article
  end

  supported_by :all do
    before :all do
      @author1 = @author_model.create(:name => 'Dan Kubb')
      @author2 = @author_model.create(:name => 'Carl Porth')

      @article1 = @author1.articles.create(:title => 'Sample Article')
      @article2 = @author2.articles.create(:title => 'Other Article')
    end

    it 'should return expected results' do
      @article_model.all.map { |article| article.author }.should == [ @author1, @author2 ]
    end
  end
end
