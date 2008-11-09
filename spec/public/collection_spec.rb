require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))
require SPEC_ROOT + 'lib/collection_shared_spec'

# run the specs once with a loaded collection and once not
[ false, true ].each do |loaded|
  describe 'Collections' do
    before do
      @loaded = loaded
    end

    # define the model prior to with_adapters
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

        @articles.entries if @loaded
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

        describe 'with no block', 'with resources' do
          before do
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
      end

      it 'should respond to a public model method with #method_missing' do
        @articles.should respond_to(:base_model)
      end

      it 'should respond to a belongs_to relationship method with #method_missing' do
        @articles.should respond_to(:original)
      end

      it 'should respond to a has relationship method with #method_missing' do
        @articles.should respond_to(:revisions)
      end

      describe '#method_missing' do
        describe 'with a public model method' do
          before do
            @return = @articles.base_model
          end

          it 'should return expected object' do
            @return.should == @model
          end
        end

        describe 'with a belongs_to relationship method' do
          before do
            @return = @collection = @articles.original
          end

          it 'should return a Collection' do
            @return.should be_kind_of(DataMapper::Collection)
          end

          it 'should return expected Collection' do
            pending 'TODO: fix logic to return correct entries' do
              @collection.should == []
            end
          end
        end

        describe 'with a has relationship method' do
          describe 'with no arguments' do
            before do
              @return = @articles.revisions
            end

            it 'should return a Collection' do
              @return.should be_kind_of(DataMapper::Collection)
            end

            it 'should return expected Collection' do
              pending 'TODO: fix logic to return correct entries' do
                @collection.should == []
              end
            end
          end

          describe 'with arguments' do
            before do
              @return = @articles.revisions(:fields => [ :id ])
            end

            it 'should return a Collection' do
              @return.should be_kind_of(DataMapper::Collection)
            end

            it 'should return expected Collection' do
              pending 'TODO: fix logic to return correct entries' do
                @collection.should == []
              end
            end
          end
        end

        describe 'with an unknown method' do
          it 'should raise an exception' do
            lambda {
              @articles.unknown
            }.should raise_error(NoMethodError)
          end
        end
      end

      it_should_behave_like 'A Collection'
    end
  end
end
