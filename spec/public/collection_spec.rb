require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))
require File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib', 'collection_shared_spec'))

describe DataMapper::Collection do
  with_adapters do
    before do
      Object.send(:remove_const, :Article) if defined?(Article)
      class Article
        include DataMapper::Resource

        property :id,      Serial
        property :title,   String
        property :content, Text
      end

      @article_repository = repository(:default)
      @model              = Article

      @article = @model.create(:title => 'Sample Article', :content => 'Sample')
      @other   = @model.create(:title => 'Other Article', :content => 'Other')

      @articles       = @model.all(:title => 'Sample Article')
      @other_articles = @model.all(:title => 'Other Article')

      @articles_query = DataMapper::Query.new(@article_repository, @model, :title => 'Sample Article')
    end

    it_should_behave_like 'A Collection'
  end
end
