require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))
require File.expand_path(File.join(File.dirname(__FILE__), '..', 'collection_shared_spec'))

describe DataMapper::Collection do
  before do
    Object.send(:remove_const, :Article) if defined?(Article)
    class Article
      include DataMapper::Resource

      property :title,   String, :key => true
      property :content, Text
    end

    @repository = repository(:default)
    @model      = Article

    @article     = @model.create(:title => 'Sample Article', :content => 'Sample')
    @other       = @model.create(:title => 'Other Article', :content => 'Other')
    @new_article = @model.new(:title => 'New Article', :content => 'Sample')

    @articles       = @model.all(:title => 'Sample Article')
    @other_articles = @model.all(:title => 'Other Article')
  end

  it_should_behave_like 'A Collection'
end
