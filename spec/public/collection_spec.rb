require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))
require File.expand_path(File.join(File.dirname(__FILE__), '..', 'collection_shared_spec'))

describe DataMapper::Collection do
  before do
    Object.send(:remove_const, :Article) if defined?(Article)
    class Article
      include DataMapper::Resource

      property :id,      Serial
      property :title,   String
      property :content, Text
    end

    @model = Article
  end

  with_adapters do
    before do
      @article_repository = repository(:default)

      @article = @model.create(:title => 'Sample Article', :content => 'Sample')
      @other   = @model.create(:title => 'Other Article', :content => 'Other')

      @articles       = @model.all(:title => 'Sample Article')
      @other_articles = @model.all(:title => 'Other Article')

      @articles_query = DataMapper::Query.new(@article_repository, @model, :title => 'Sample Article')
    end

    it_should_behave_like 'A Collection'

    # TODO: move to semipublic specs
    it 'should respond to #load' do
      @articles.should respond_to(:load)
    end

    # TODO: move to semipublic specs
    describe '#load' do
      before do
        @return = @resource = @articles.load([ 1, 'Title' ])
      end

      it 'should return a Resource' do
        @return.should be_kind_of(DataMapper::Resource)
      end

      it 'should be an initialized Resource' do
        @resource.should == @model.new(:id => 1, :title => 'Title')
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
  end
end
