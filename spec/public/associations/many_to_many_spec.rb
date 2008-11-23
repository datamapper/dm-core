require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'spec_helper'))

# run the specs once with a loaded association and once not
[ false, true ].each do |loaded|
  describe 'Many to Many Associations' do
    extend DataMapper::Spec::CollectionHelpers::GroupMethods

    self.loaded = loaded

    # define the model prior to supported_by
    before do
      class Author
        include DataMapper::Resource

        property :id,   Serial
        property :name, String

        has n, :articles, :through => Resource
      end

      class Article
        include DataMapper::Resource

        property :id,      Serial
        property :title,   String
        property :content, Text

        has n, :authors, :through => Resource
        belongs_to :original, :class_name => 'Article'
        has n, :revisions, :class_name => 'Article'
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

      it_should_behave_like 'A public Collection'
    end
  end
end
