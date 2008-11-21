require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

# run the specs once with a loaded collection and once not
[ false, true ].each do |loaded|
  describe DataMapper::Collection do
    extend DataMapper::Spec::CollectionHelpers::GroupMethods

    self.loaded = loaded

    before do
      Object.send(:remove_const, :Article) if defined?(Article)
      class Article
        include DataMapper::Resource

        property :id,      Serial
        property :title,   String
        property :content, Text

        belongs_to :original, :class_name => 'Article'
        has n, :revisions, :class_name => 'Article'
      end
    end

    supported_by :all do
      before do
        @article_repository = repository(:default)
        @model              = Article
        @articles_query     = DataMapper::Query.new(@article_repository, @model, :title => 'Sample Article')

        @article = @model.create(:title => 'Sample Article', :content => 'Sample')
        @other   = @model.create(:title => 'Other Article',  :content => 'Other')

        @articles       = @model.all(@articles_query)
        @other_articles = @model.all(:title => 'Other Article')

        @articles.entries if loaded
      end

      it_should_behave_like 'A public Collection'
    end
  end
end
