require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

describe DataMapper::Model do
  before :all do
    module ::Blog
      class Article
        include DataMapper::Resource

        property :id,      Serial
        property :title,   String, :nullable => false
        property :content, Text
        property :author,  String, :nullable => false

        belongs_to :original, self, :nullable => true
        has n, :revisions, self, :child_key => [ :original_id ]
        has 1, :previous,  self, :child_key => [ :original_id ], :order => [ :id.desc ]
      end
    end

    @article_model = Blog::Article
  end

  supported_by :all do
    before :all do
      @author = 'Dan Kubb'

      @original = @article_model.create(:title => 'Original Article',                                               :author => @author)
      @article  = @article_model.create(:title => 'Sample Article',   :content => 'Sample', :original => @original, :author => @author)
      @other    = @article_model.create(:title => 'Other Article',    :content => 'Other',                          :author => @author)
    end

    it { @article_model.should respond_to(:copy) }

    describe '#copy' do
      with_alternate_adapter do
        describe 'between identical models' do
          before :all do
            @return = @resources = @article_model.copy(@repository.name, @alternate_adapter.name)
          end

          it 'should return an Enumerable' do
            @return.should be_a_kind_of(Enumerable)
          end

          it 'should return Resources' do
            @return.each { |resource| resource.should be_a_kind_of(DataMapper::Resource) }
          end

          it 'should have each Resource set to the expected Repository' do
            @resources.each { |resource| resource.repository.name.should == @alternate_adapter.name }
          end

          it 'should create the Resources in the expected Repository' do
            @article_model.all(:repository => DataMapper.repository(@alternate_adapter.name)).should == @resources
          end
        end

        describe 'between different models' do
          before :all do
            @other.destroy
            @article.destroy
            @original.destroy

            # make sure the default repository is empty
            @article_model.all(:repository => @repository).should be_empty

            # add an extra property to the alternate model
            DataMapper.repository(@alternate_adapter.name) do
              @article_model.property :status, String, :default => 'new'
            end

            if @article_model.respond_to?(:auto_migrate!)
              @article_model.auto_migrate!(@alternate_adapter.name)
            end

            # add new resources to the alternate repository
            DataMapper.repository(@alternate_adapter.name) do
              @heff1 = @article_model.create(:title => 'Alternate Repository', :author => @author)
            end

            # copy from the alternate to the default repository
            @return = @resources = @article_model.copy(@alternate_adapter.name, :default)
          end

          it 'should return an Enumerable' do
            @return.should be_a_kind_of(Enumerable)
          end

          it 'should return Resources' do
            @return.each { |resource| resource.should be_a_kind_of(DataMapper::Resource) }
          end

          it 'should have each Resource set to the expected Repository' do
            @resources.each { |resource| resource.repository.name.should == :default }
          end

          it 'should create the Resources in the expected Repository' do
            @article_model.all.should == @resources
          end
        end
      end
    end
  end
end
