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

      @model = Article

      @article  = @model.create(:title => 'Sample Article', :content => 'Sample')
      @articles = @model.all(:title => 'Sample Article')
    end

    it 'should respond to #default_attributes' do
      @articles.should respond_to(:default_attributes)
    end

    describe '#default_attributes' do
      it 'should have specs'
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

    it 'should respond to #model' do
      @articles.should respond_to(:model)
    end

    describe '#model' do
      it 'should have specs'
    end

    it 'should respond to #properties' do
      @articles.should respond_to(:properties)
    end

    describe '#properties' do
      it 'should have specs'
    end

    it 'should respond to #query' do
      @articles.should respond_to(:query)
    end

    describe '#query' do
      it 'should have specs'
    end

    it 'should respond to #relationships' do
      @articles.should respond_to(:relationships)
    end

    describe '#relationships' do
      it 'should have specs'
    end

    it 'should respond to #repository' do
      @articles.should respond_to(:repository)
    end

    describe '#repository' do
      it 'should have specs'
    end
  end
end
