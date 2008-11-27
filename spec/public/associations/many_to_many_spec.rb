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

        # TODO: move conditions down to before block once author.articles(query)
        # returns a OneToMany::Proxy object (and not Collection as it does now)
        has n, :sample_articles, :title.eql => 'Sample Article', :class_name => 'Article', :through => Resource
        has n, :other_articles,  :title     => 'Other Article',  :class_name => 'Article', :through => Resource
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

      @model = Article
    end

    supported_by :all do
      before do
        @author1 = Author.create(:name => 'Dan Kubb')
        @author2 = Author.create(:name => 'Lawrence Pit')

        @original = @model.create(:title => 'Original Article')
        @article  = @model.create(:title => 'Sample Article', :content => 'Sample', :original => @original)
        @other    = @model.create(:title => 'Other Article',  :content => 'Other')

        #ArticleAuthor.create(:article_id => @article.id, :author_id => @author1.id)
        #ArticleAuthor.create(:article_id => @other.id,   :author_id => @author1.id)

        @author1.sample_articles << @article
        @author1.other_articles  << @other

        @articles       = @author1.sample_articles
        @other_articles = @author1.other_articles
      end

      it_should_behave_like 'A public Collection'
    end
  end
end
