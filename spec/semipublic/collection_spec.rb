require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

# run the specs once with a loaded collection and once not
[ false, true ].each do |loaded|
  describe DataMapper::Collection do
    extend DataMapper::Spec::CollectionHelpers::GroupMethods

    self.loaded = loaded

    before do
      class Article
        include DataMapper::Resource

        property :id,      Serial
        property :title,   String
        property :content, Text
      end
    end

    supported_by :all do
      before do
        @article_repository = repository(:default)
        @model              = Article
        @articles_query     = DataMapper::Query.new(@article_repository, @model, :title => 'Sample Article')

        @article = @model.create(:title => 'Sample Article', :content => 'Sample')

        @articles = @model.all(@articles_query)

        @articles.entries if loaded
      end

      it { DataMapper::Collection.should respond_to(:new) }

      describe '.new' do
        describe 'with resources' do
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

        describe 'with no resources' do
          before do
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

      it { @articles.should respond_to(:properties) }

      describe '#properties' do
        before do
          @return = @properties = @articles.properties
        end

        it 'should return a PropertySet' do
          @return.should be_kind_of(DataMapper::PropertySet)
        end

        it 'should be expected properties' do
          @properties.to_a.should == @articles_query.fields
        end
      end

      it { @articles.should respond_to(:query) }

      describe '#query' do
        before do
          @return = @articles.query
        end

        it 'should return a Query' do
          @return.should be_kind_of(DataMapper::Query)
        end

        it 'should return expected Query' do
          pending 'TODO: Fix Model.all to not unecessarily create Query copies' do
            @return.should be_equal(@articles_query)
          end
        end
      end

      it { @articles.should respond_to(:relationships) }

      describe '#relationships' do
        before do
          @return = @relationships = @articles.relationships
        end

        it 'should return a Hash' do
          @return.should be_kind_of(Hash)
        end

        it 'should return expected Hash' do
          @return.should be_equal(@model.relationships(@article_repository.name))
        end
      end

      it { @articles.should respond_to(:repository) }

      describe '#repository' do
        before do
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
