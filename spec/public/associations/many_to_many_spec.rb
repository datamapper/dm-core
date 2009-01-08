require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'spec_helper'))

# run the specs once with a loaded association and once not
[ false, true ].each do |loaded|
  describe 'Many to Many Associations' do
    before do
      pending 'Many To Many Associations needs to be implemented'
    end

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
        # returns a ManyToMany::Collection object
        has n, :sample_articles, :title => 'Sample Article', :class => 'Article', :through => Resource
        has n, :other_articles,  :title => 'Other Article',  :class => 'Article', :through => Resource
      end

      class Article
        include DataMapper::Resource

        property :id,      Serial
        property :title,   String
        property :content, Text

        has n, :authors, :through => Resource
        belongs_to :original, :class => self
        has n, :revisions,    :class => self
      end

      @model = Article
    end

    supported_by :all do
      before do
        @author = Author.create(:name => 'Dan Kubb')

        @original = @author.articles.create(:title => 'Original Article')
        @article  = @author.articles.create(:title => 'Sample Article', :content => 'Sample', :original => @original)
        @other    = @author.articles.create(:title => 'Other Article',  :content => 'Other')

        @articles       = @author.articles(:title => 'Sample Article')
        @other_articles = @author.articles(:title => 'Other Article')
      end

      it_should_behave_like 'A public Collection'
    end
  end
end
