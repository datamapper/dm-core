require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

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

      @article  = @model.create(:title => 'Sample Article', :content => 'Sample')
      @articles = @model.all(:title => 'Sample Article')

      @articles_query = DataMapper::Query.new(@article_repository, @model, :title => 'Sample Article')
    end

    it 'should respond to #default_attributes' do
      @articles.should respond_to(:default_attributes)
    end

    describe '#default_attributes' do
      before do
        @return = @articles.default_attributes
      end

      it 'should return a Hash' do
        @return.should be_kind_of(Hash)
      end

      it 'should return expected values' do
        @return.should == { :title => 'Sample Article' }
      end
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
        @resource.collection.object_id.should == @articles.object_id
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
        @return.should == @articles_query
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
        @return.should == @model.relationships(@article_repository.name)
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
