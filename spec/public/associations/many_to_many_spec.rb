require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'spec_helper'))

share_examples_for 'A Limited Many to Many Collection' do
  describe '#destroy!' do
    describe 'on a limited collection' do
      before :all do
        @other   = @articles.create
        @limited = @articles.all(:limit => 1)

        @return = @limited.destroy!
      end

      it 'should only remove the join resource for the destroyed resource' do
        @join_model.all.should_not be_empty
      end
    end
  end
end

# run the specs once with a loaded association and once not
[ false, true ].each do |loaded|
  describe 'Many to Many Associations with :through => Resource' do
    extend DataMapper::Spec::CollectionHelpers::GroupMethods

    self.loaded = loaded

    # define the model prior to supported_by
    before :all do
      module ::Blog
        class Author
          include DataMapper::Resource

          property :id,   Serial
          property :name, String

          has n, :articles, :through => Resource
        end

        class Article
          include DataMapper::Resource

          property :id,       Serial
          property :title,    String, :required => true
          property :content,  Text
          property :subtitle, String

          has n, :authors, :through => Resource
          belongs_to :original, self, :required => false
          has n, :revisions, self, :child_key => [ :original_id ]
          has 1, :previous,  self, :child_key => [ :original_id ], :order => [ :id.desc ]
          has n, :publications, :through => Resource
        end

        class Publication
          include DataMapper::Resource

          property :id,   Serial
          property :name, String

          has n, :articles, :through => Resource
        end
      end

      @author_model      = Blog::Author
      @article_model     = Blog::Article
      @publication_model = Blog::Publication

      # initialize the join model
      Blog::Author.relationships(:default)[:articles].through

      @join_model = Blog::ArticleAuthor
    end

    supported_by :all do
      before :all do
        @author = @author_model.create(:name => 'Dan Kubb')

        @original = @author.articles.create(:title => 'Original Article')
        @article  = @author.articles.create(:title => 'Sample Article', :content => 'Sample', :original => @original)
        @other    = @author.articles.create(:title => 'Other Article',  :content => 'Other')

        # load the targets without references to a single source
        load_collection = lambda do |query|
          @author_model.get(*@author.key).articles(query)
        end

        @articles       = load_collection.call(:title => 'Sample Article')
        @other_articles = load_collection.call(:title => 'Other Article')

        @articles.entries if loaded
      end

      it_should_behave_like 'A public Collection'
      it_should_behave_like 'A public Association Collection'
      it_should_behave_like 'A Collection supporting Strategic Eager Loading' unless loaded
      it_should_behave_like 'Finder Interface'
      it_should_behave_like 'Collection Finder Interface'
      it_should_behave_like 'A Limited Many to Many Collection'
    end
  end

  describe 'Many to Many Associations :through => one_to_many' do
    extend DataMapper::Spec::CollectionHelpers::GroupMethods

    self.loaded = loaded

    # define the model prior to supported_by
    before :all do
      module ::Blog
        class Author
          include DataMapper::Resource

          property :id,   Serial
          property :name, String

          has n, :sites
          has n, :articles, :through => :sites
        end

        class Site
          include DataMapper::Resource

          property :name, String, :key => true, :default => 'default'

          belongs_to :author
          has n, :articles
        end

        class Article
          include DataMapper::Resource

          property :id,      Serial
          property :title,   String, :required => true
          property :content, Text
          property :subtitle, String

          property :site_name, String, :default => 'default'

          belongs_to :site
          has n, :authors, :through => :site
          belongs_to :original, self, :required => false
          has n, :revisions, self, :child_key => [ :original_id ]
          has 1, :previous,  self, :child_key => [ :original_id ], :order => [ :id.desc ]
          has n, :publications, :through => Resource
        end

        class Publication
          include DataMapper::Resource

          property :id,   Serial
          property :name, String

          has n, :articles, :through => Resource
        end
      end

      @author_model      = Blog::Author
      @article_model     = Blog::Article
      @publication_model = Blog::Publication

      @join_model = Blog::Site
    end

    supported_by :all do
      before :all do
        @author = @author_model.create(:name => 'Dan Kubb')

        @original_site = @author.sites.create(:name => 'original')
        @article_site  = @author.sites.create(:name => 'article')
        @other_site    = @author.sites.create(:name => 'other')

        @original = @original_site.articles.create(:title => 'Original Article')
        @article  = @article_site.articles.create(:title => 'Sample Article', :content => 'Sample', :original => @original)
        @other    = @other_site.articles.create(:title => 'Other Article',  :content => 'Other')

        # load the targets without references to a single source
        load_collection = lambda do |query|
          @author_model.get(*@author.key).articles(query)
        end

        @articles       = load_collection.call(:title => 'Sample Article')
        @other_articles = load_collection.call(:title => 'Other Article')

        @articles.entries if loaded
      end

      it_should_behave_like 'A public Collection'
      it_should_behave_like 'A public Association Collection'
      it_should_behave_like 'A Collection supporting Strategic Eager Loading' unless loaded
      it_should_behave_like 'Finder Interface'
      it_should_behave_like 'Collection Finder Interface'
      it_should_behave_like 'A Limited Many to Many Collection'
    end
  end
end
