require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))
require File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib', 'collection_shared_spec'))

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

      @articles_query = DataMapper::Query.new(repository(:default), @model, :title => 'Sample Article')
    end

    it 'should respond to .new' do
      DataMapper::Collection.should respond_to(:new)
    end

    describe '.new' do
      describe 'with no block' do
        before do
          @return = @collection = DataMapper::Collection.new(@articles_query)
        end

        it 'should return a Collection' do
          @return.should be_kind_of(DataMapper::Collection)
        end

        it 'should not be loaded' do
          @return.should_not be_loaded
        end

        it 'should be empty when a kicker is called' do
          @collection.entries.should be_empty
        end
      end

      describe 'with a block' do
        before do
          @return = @collection = DataMapper::Collection.new(@articles_query) do |c|
            c.load([ 99, 'Sample Article' ])
          end
        end

        it 'should return a Collection' do
          @return.should be_kind_of(DataMapper::Collection)
        end

        it 'should not be loaded' do
          @return.should_not be_loaded
        end

        it 'should lazy load when a kicker is called' do
          @collection.entries.should == [ @model.new(:id => 99, :title => 'Sample Article') ]
        end
      end
    end

    it_should_behave_like 'A Collection'
  end
end
