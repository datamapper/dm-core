require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

# run the specs once with a loaded collection and once not
[ false, true ].each do |loaded|
  describe DataMapper::Collection do
    extend DataMapper::Spec::CollectionHelpers::GroupMethods

    self.loaded = loaded

    before :all do
      module ::Blog
        class Article
          include DataMapper::Resource

          property :id,      Serial
          property :title,   String
          property :content, Text
          property :subtitle, String
        end
      end

      @article_model = Blog::Article
    end

    supported_by :all do
      before :all do
        @article_repository = @repository
        @articles_query     = DataMapper::Query.new(@article_repository, @article_model, :title => 'Sample Article')

        @article = @article_model.create(:title => 'Sample Article', :content => 'Sample')

        @articles = @article_model.all(@articles_query)

        @articles.entries if loaded
      end

      it { DataMapper::Collection.should respond_to(:new) }

      describe '.new' do
        describe 'with resources' do
          before :all do
            @return = @collection = DataMapper::Collection.new(@articles_query, [ @article ])
          end

          it 'should return a Collection' do
            @return.should be_kind_of(DataMapper::Collection)
          end

          it 'should be loaded' do
            @return.should be_loaded
          end

          it 'should contain the article' do
            @collection.should == [ @article ]
          end
        end

        describe 'with no resources' do
          before :all do
            @return = @collection = DataMapper::Collection.new(@articles_query)
          end

          it 'should return a Collection' do
            @return.should be_kind_of(DataMapper::Collection)
          end

          it 'should not be loaded' do
            @return.should_not be_loaded
          end

          it 'should contain the article' do
            @collection.should == [ @article ]
          end
        end
      end

      it { @articles.should respond_to(:query) }

      describe '#query' do
        before :all do
          @return = @articles.query
        end

        it 'should return a Query' do
          @return.should be_kind_of(DataMapper::Query)
        end

        it 'should return expected Query' do
          @return.should eql(@articles_query)
        end
      end

      it { @articles.should respond_to(:repository) }

      describe '#repository' do
        before :all do
          @return = @repository = @articles.repository
        end

        it 'should return a Repository' do
          @return.should be_kind_of(DataMapper::Repository)
        end

        it 'should be expected Repository' do
          @repository.should == @article_repository
        end
      end
    end
  end
end
