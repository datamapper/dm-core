require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'spec_helper'))

# TODO: see if we can use this shared spec, and alot of the specs below
# for the ManyToMany association specs

share_examples_for 'It can transfer a Resource from another association' do
  before :all do
    %w[ @resource @original ].each do |ivar|
      raise "+#{ivar}+ should be defined in before block" unless instance_variable_get(ivar)
    end
  end

  it 'should relate the Resource to the Collection' do
    @resource.collection.should equal(@articles)
  end

  it 'should remove the Resource from the original Collection' do
    pending do
      @original.should_not be_include(@resource)
    end
  end
end

# run the specs once with a loaded association and once not
[ false, true ].each do |loaded|
  describe 'One to Many Associations' do
    extend DataMapper::Spec::CollectionHelpers::GroupMethods

    self.loaded = loaded

    # define the model prior to supported_by
    before :all do
      module ::Blog
        class Author
          include DataMapper::Resource

          property :id,   Serial
          property :name, String

          has n, :articles
        end

        class Article
          include DataMapper::Resource

          property :id,      Serial
          property :title,   String, :nullable => false
          property :content, Text

          belongs_to :author, :nullable => true
          belongs_to :original, self, :nullable => true
          has n, :revisions, self, :child_key => [ :original_id ]
          has 1, :previous,  self, :child_key => [ :original_id ], :order => [ :id.desc ]
        end
      end

      @author_model  = Blog::Author
      @article_model = Blog::Article
    end

    supported_by :all do
      before :all do
        @author  = @author_model.create(:name => 'Dan Kubb')

        @original = @author.articles.create(:title => 'Original Article')
        @article  = @author.articles.create(:title => 'Sample Article', :content => 'Sample', :original => @original)
        @other    = @author.articles.create(:title => 'Other Article',  :content => 'Other')

        # load the targets without references to a single source
        load_collection = lambda do |query|
          @author_model.get(*@author.key).articles(query)
        end

        @articles       = load_collection.call(:title => 'Sample Article')
        @other_articles = load_collection.call(:title => 'Other Article')

        @articles.entries if loaded
      end

      it_should_behave_like 'A public Collection'
      it_should_behave_like 'A Collection supporting Strategic Eager Loading'

      describe '#<<' do
        describe 'when provided a Resource belonging to another association' do
          before :all do
            @original = @other_articles
            @resource = @original.first
            @return = @articles << @resource
          end

          it 'should return a Collection' do
            @return.should be_kind_of(DataMapper::Collection)
          end

          it 'should return self' do
            @return.should equal(@articles)
          end

          it_should_behave_like 'It can transfer a Resource from another association'
        end
      end

      describe '#collect!' do
        describe 'when provided a Resource belonging to another association' do
          before :all do
            @original = @other_articles
            @resource = @original.first
            @return = @articles.collect! { |resource| @resource }
          end

          it 'should return a Collection' do
            @return.should be_kind_of(DataMapper::Collection)
          end

          it 'should return self' do
            @return.should equal(@articles)
          end

          it_should_behave_like 'It can transfer a Resource from another association'
        end
      end

      describe '#concat' do
        describe 'when provided a Resource belonging to another association' do
          before :all do
            @original = @other_articles
            @resource = @original.first
            @return = @articles.concat([ @resource ])
          end

          it 'should return a Collection' do
            @return.should be_kind_of(DataMapper::Collection)
          end

          it 'should return self' do
            @return.should equal(@articles)
          end

          it_should_behave_like 'It can transfer a Resource from another association'
        end
      end

      describe '#create' do
        describe 'when the parent is not saved' do
          it 'should raise an exception' do
            author = @author_model.new(:name => 'Dan Kubb')
            lambda {
              author.articles.create
            }.should raise_error(DataMapper::UnsavedParentError, 'The source must be saved before creating a resource')
          end
        end
      end

      describe '#destroy' do
        describe 'when the parent is not saved' do
          it 'should raise an exception' do
            author = @author_model.new(:name => 'Dan Kubb')
            lambda {
              author.articles.destroy
            }.should raise_error(DataMapper::UnsavedParentError, 'The source must be saved before mass-deleting the collection')
          end
        end
      end

      describe '#destroy!' do
        describe 'when the parent is not saved' do
          it 'should raise an exception' do
            author = @author_model.new(:name => 'Dan Kubb')
            lambda {
              author.articles.destroy!
            }.should raise_error(DataMapper::UnsavedParentError, 'The source must be saved before mass-deleting the collection')
          end
        end
      end

      describe '#insert' do
        describe 'when provided a Resource belonging to another association' do
          before :all do
            @original = @other_articles
            @resource = @original.first
            @return = @articles.insert(0, @resource)
          end

          it 'should return a Collection' do
            @return.should be_kind_of(DataMapper::Collection)
          end

          it 'should return self' do
            @return.should equal(@articles)
          end

          it_should_behave_like 'It can transfer a Resource from another association'
        end
      end

      it 'should respond to a public collection method with #method_missing' do
        @articles.respond_to?(:to_a)
      end

      describe '#method_missing' do
        describe 'with a public collection method' do
          before :all do
            @return = @articles.to_a
          end

          it 'should return expected object' do
            @return.should == @articles
          end
        end

        describe 'with unknown method' do
          it 'should raise an exception' do
            lambda {
              @articles.unknown
            }.should raise_error(NoMethodError)
          end
        end
      end

      describe '#new' do
        before :all do
          @resource = @author.articles.new
        end

        it 'should associate the Resource to the Collection' do
          @resource.author.should == @author
        end
      end

      describe '#push' do
        describe 'when provided a Resource belonging to another association' do
          before :all do
            @original = @other_articles
            @resource = @original.first
            @return = @articles.push(@resource)
          end

          it 'should return a Collection' do
            @return.should be_kind_of(DataMapper::Collection)
          end

          it 'should return self' do
            @return.should equal(@articles)
          end

          it_should_behave_like 'It can transfer a Resource from another association'
        end
      end

      describe '#replace' do
        describe 'when provided a Resource belonging to another association' do
          before :all do
            @original = @other_articles
            @resource = @original.first
            @return = @articles.replace([ @resource ])
          end

          it 'should return a Collection' do
            @return.should be_kind_of(DataMapper::Collection)
          end

          it 'should return self' do
            @return.should equal(@articles)
          end

          it 'should relate the Resource to the Collection' do
            @resource.collection.should equal(@articles)
          end

          it_should_behave_like 'It can transfer a Resource from another association'
        end
      end

      describe '#unshift' do
        describe 'when provided a Resource belonging to another association' do
          before :all do
            @original = @other_articles
            @resource = @original.first
            @return = @articles.unshift(@resource)
          end

          it 'should return a Collection' do
            @return.should be_kind_of(DataMapper::Collection)
          end

          it 'should return self' do
            @return.should equal(@articles)
          end

          it_should_behave_like 'It can transfer a Resource from another association'
        end
      end

      describe '#update' do
        describe 'when the parent is not saved' do
          it 'should raise an exception' do
            author = @author_model.new(:name => 'Dan Kubb')
            lambda {
              author.articles.update(:title => 'New Title')
            }.should raise_error(DataMapper::UnsavedParentError, 'The source must be saved before mass-updating the collection')
          end
        end
      end

      describe '#update!' do
        describe 'when the parent is not saved' do
          it 'should raise an exception' do
            author = @author_model.new(:name => 'Dan Kubb')
            lambda {
              author.articles.update!(:title => 'New Title')
            }.should raise_error(DataMapper::UnsavedParentError, 'The source must be saved before mass-updating the collection')
          end
        end
      end
    end
  end
end
