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

    @article_repository = repository(:default)
    @model              = Article

    @article = @model.create(:title => 'Sample Article', :content => 'Sample')
    @other   = @model.create(:title => 'Other Article', :content => 'Other')

    @articles       = @model.all(:title => 'Sample Article')
    @other_articles = @model.all(:title => 'Other Article')

    @articles_query = DataMapper::Query.new(@article_repository, @model, :title => 'Sample Article')
  end

  it_should_behave_like 'A Collection'

  it 'should respond to #load' do
    @articles.should respond_to(:load)
  end

  describe '#load' do
    before do
      @return = @resource = @articles.load(%w[ Title ])
    end

    it 'should return a Resource' do
      @return.should be_kind_of(DataMapper::Resource)
    end

    it 'should be an initialized Resource' do
      @resource.should == @model.new(:title => 'Title')
    end

    it 'should not be a new Resource' do
      @resource.should_not be_new_record
    end

    it 'should add the Resource to the Collection' do
      @articles.should include(@resource)
    end

    it 'should set the Resource to reference the Collection' do
      @resource.collection.object_id.should == @articles.object_id
    end
  end

  it 'should respond to #query' do
    @articles.should respond_to(:query)
  end

  describe '#query' do
    before do
      @return = @articles.query
    end

    it 'should return a Query' do
      @return.should be_kind_of(DataMapper::Query)
    end

    it 'should return the associated Query' do
      @return.should == @articles_query
    end
  end

  it 'should respond to #repository' do
    @articles.should respond_to(:repository)
  end

  describe '#repository' do
    before do
      @return = @repository = @articles.repository
    end

    it 'should return a Repository' do
      @return.should be_kind_of(DataMapper::Repository)
    end

    it 'should return the associated Repository' do
      @return.should == @article_repository
    end
  end
end
