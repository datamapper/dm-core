require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

# run the specs once with a loaded collection and once not
[ false, true ].each do |loaded|
  describe DataMapper::Collection do

    # define the model prior to supported_by
    before do
      Object.send(:remove_const, :Article) if defined?(Article)
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

      it 'should respond to #load' do
        @articles.should respond_to(:load)
      end

      describe '#load' do
        before do
          @return = @resource = @articles.load([ 99, 'Title' ])
        end

        it 'should return a Resource' do
          @return.should be_kind_of(DataMapper::Resource)
        end

        it 'should be an initialized Resource' do
          @resource.should == @model.new(:id => 99, :title => 'Title')
        end

        it 'should not be a new Resource' do
          @resource.should_not be_new_record
        end

        it 'should add the Resource to the Collection' do
          @articles.should include(@resource)
        end

        it 'should set the Resource to reference the Collection' do
          @resource.collection.should be_equal(@articles)
        end
      end

      it 'should respond to #properties' do
        @articles.should respond_to(:properties)
      end

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

        it 'should return expected Query' do
          pending 'TODO: Fix Model.all to not unecessarily create Query copies' do
            @return.should be_equal(@articles_query)
          end
        end
      end

      it 'should respond to #relationships' do
        @articles.should respond_to(:relationships)
      end

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

        it 'should be expected Repository' do
          @repository.should == @article_repository
        end
      end
    end
  end
end
