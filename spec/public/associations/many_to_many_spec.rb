require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'spec_helper'))

# run the specs once with a loaded association and once not
[ false, true ].each do |loaded|
  describe 'Many to Many Associations' do
    extend DataMapper::Spec::CollectionHelpers::GroupMethods

    self.loaded = loaded

    # define the model prior to supported_by
    before :all do
      class ::Author
        include DataMapper::Resource

        property :id,   Serial
        property :name, String

        has n, :articles, :through => Resource
      end

      class ::Article
        include DataMapper::Resource

        property :id,      Serial
        property :title,   String, :nullable => false
        property :content, Text

        has n, :authors, :through => Resource
        belongs_to :original, :model => self, :nullable => true
        has n, :revisions, :model => self, :child_key => [ :original_id ]
        has 1, :previous,  :model => self, :child_key => [ :original_id ], :order => [ :id.desc ]
      end

      @model = Article
    end

    supported_by :all do
      before :all do
        @author = Author.create(:name => 'Dan Kubb')

        @original = @author.articles.create(:title => 'Original Article')
        @article  = @author.articles.create(:title => 'Sample Article', :content => 'Sample', :original => @original)
        @other    = @author.articles.create(:title => 'Other Article',  :content => 'Other')

        # load the targets without references to a single source
        load_collection = lambda do |query|
          Author.get(*@author.key).articles(query)
        end

        @articles       = load_collection.call(:title => 'Sample Article')
        @other_articles = load_collection.call(:title => 'Other Article')

        @articles.entries if loaded
      end

      it_should_behave_like 'A public Collection'

      # TODO: make this pass
      #it_should_behave_like 'A Collection supporting Strategic Eager Loading' unless loaded

      describe '#destroy!' do
        describe 'on a limited collection' do
          before :all do
            @other   = @articles.create
            @limited = @articles.all(:limit => 1)

            @return = @limited.destroy!
          end

          it 'should only remove the join resource for the destroyed resource' do
            ArticleAuthor.all.should_not be_empty
          end
        end
      end
    end
  end
end
