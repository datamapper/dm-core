require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'spec_helper'))
require SPEC_ROOT + 'lib/collection_shared_spec'

# TODO: test loaded and unloaded behavior

describe DataMapper::Associations::ManyToMany::Proxy do

  # define the model prior to with_adapters
  before do
    Object.send(:remove_const, :Author) if defined?(Author)
    class Author
      include DataMapper::Resource

      property :id,   Serial
      property :name, String

      has n, :articles, :through => Resource
    end

    Object.send(:remove_const, :Article) if defined?(Article)
    class Article
      include DataMapper::Resource

      property :id,      Serial
      property :title,   String
      property :content, Text

      has n, :authors, :through => Resource
    end
  end

  supported_by :all do
    before do
      @article_repository = repository(:default)
      @model              = Article

      @article = @model.create(:title => 'Sample Article', :content => 'Sample')
      @other   = @model.create(:title => 'Other Article',  :content => 'Other')

      @author1  = Author.create(:name => 'Dan Kubb')
      @author2  = Author.create(:name => 'Lawrence Pit')

      #ArticleAuthor.create(:article_id => @article.id, :author_id => @author1.id)
      @author1.articles << @article

      @articles       = @author1.articles
      @other_articles = [@other]
    end

    it_should_behave_like 'A Collection'
  end
end
