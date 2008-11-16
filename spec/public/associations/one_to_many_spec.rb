require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'spec_helper'))

share_examples_for 'It can transfer a Resource from another association' do
  before do
    %w[ @resource @original ].each do |ivar|
      raise "+#{ivar}+ should be defined in before block" unless instance_variable_get(ivar)
    end
  end

  it 'should relate the Resource to the Collection' do
    @resource.collection.should be_equal(@articles)
  end

  it 'should remove the Resource from the original Collection' do
    pending do
      @original.should_not include(@resource)
    end
  end
end

# run the specs once with a loaded association and once not
[ false, true ].each do |loaded|
  describe 'One to Many Associations' do
    extend CollectionSharedSpec::GroupMethods

    self.loaded = loaded

    # define the model prior to supported_by
    before do
      Object.send(:remove_const, :Author) if defined?(Author)
      class Author
        include DataMapper::Resource

        property :id,   Serial
        property :name, String

        has n, :articles

        # TODO: move conditions down to before block once author.articles(query)
        # returns a OneToMany::Proxy object (and not Collection as it does now)
        has n, :sample_articles, :title.eql => 'Sample Article', :class_name => 'Article'
        has n, :other_articles,  :title     => 'Other Article',  :class_name => 'Article'
      end

      Object.send(:remove_const, :Article) if defined?(Article)
      class Article
        include DataMapper::Resource

        property :id,      Serial
        property :title,   String
        property :content, Text

        belongs_to :author
        belongs_to :original, :class_name => 'Article'
        has n, :revisions, :class_name => 'Article'
      end
    end

    supported_by :all do
      before do
        @article_repository = repository(:default)
        @model              = Article

        @author  = Author.create(:name => 'Dan Kubb')
        @article = @model.create(:title => 'Sample Article', :content => 'Sample', :author => @author)
        @other   = @model.create(:title => 'Other Article',  :content => 'Other',  :author => @author)

        @articles       = @author.sample_articles
        @other_articles = @author.other_articles
      end

      it_should_behave_like 'A Collection'

      describe '#<<' do
        describe 'when provided a Resource belonging to another association' do
          before do
            @original = @other_articles
            @resource = @original.first
            @return = @articles << @resource
          end

          it 'should return a Collection' do
            @return.should be_kind_of(DataMapper::Collection)
          end

          it 'should return self' do
            @return.should be_equal(@articles)
          end

          it_should_behave_like 'It can transfer a Resource from another association'
        end
      end

      describe '#build' do
        before do
          @resource = @author.articles.build
        end

        it 'should associate the Resource to the Collection' do
          @resource.author.should == @author
        end
      end

      describe '#collect!' do
        describe 'when provided a Resource belonging to another association' do
          before do
            @original = @other_articles
            @resource = @original.first
            @return = @articles.collect! { |r| @resource }
          end

          it 'should return a Collection' do
            @return.should be_kind_of(DataMapper::Collection)
          end

          it 'should return self' do
            @return.should be_equal(@articles)
          end

          it_should_behave_like 'It can transfer a Resource from another association'
        end
      end

      describe '#concat' do
        describe 'when provided a Resource belonging to another association' do
          before do
            @original = @other_articles
            @resource = @original.first
            @return = @articles.concat([ @resource ])
          end

          it 'should return a Collection' do
            @return.should be_kind_of(DataMapper::Collection)
          end

          it 'should return self' do
            @return.should be_equal(@articles)
          end

          it_should_behave_like 'It can transfer a Resource from another association'
        end
      end

      describe '#create' do
        describe 'when the parent is not saved' do
          it 'should raise an exception' do
            author = Author.new(:name => 'Dan Kubb')
            lambda {
              author.sample_articles.create
            }.should raise_error(DataMapper::Associations::UnsavedParentError, 'The parent must be saved before creating a Resource')
          end
        end
      end

      describe '#destroy' do
        describe 'when the parent is not saved' do
          it 'should raise an exception' do
            author = Author.new(:name => 'Dan Kubb')
            lambda {
              author.sample_articles.destroy
            }.should raise_error(DataMapper::Associations::UnsavedParentError, 'The parent must be saved before mass-deleting the association')
          end
        end
      end

      describe '#destroy!' do
        describe 'when the parent is not saved' do
          it 'should raise an exception' do
            author = Author.new(:name => 'Dan Kubb')
            lambda {
              author.sample_articles.destroy!
            }.should raise_error(DataMapper::Associations::UnsavedParentError, 'The parent must be saved before mass-deleting the association without validation')
          end
        end
      end

      describe '#insert' do
        describe 'when provided a Resource belonging to another association' do
          before do
            @original = @other_articles
            @resource = @original.first
            @return = @articles.insert(0, @resource)
          end

          it 'should return a Collection' do
            @return.should be_kind_of(DataMapper::Collection)
          end

          it 'should return self' do
            @return.should be_equal(@articles)
          end

          it_should_behave_like 'It can transfer a Resource from another association'
        end
      end

      it 'should respond to a public collection method with #method_missing' do
        @articles.respond_to?(:to_a)
      end

      describe '#method_missing' do
        describe 'with a public collection method' do
          before do
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

      describe '#push' do
        describe 'when provided a Resource belonging to another association' do
          before do
            @original = @other_articles
            @resource = @original.first
            @return = @articles.push(@resource)
          end

          it 'should return a Collection' do
            @return.should be_kind_of(DataMapper::Collection)
          end

          it 'should return self' do
            @return.should be_equal(@articles)
          end

          it_should_behave_like 'It can transfer a Resource from another association'
        end
      end

      describe '#replace' do
        # TODO: update Collection#replace to handle this use case
        describe 'when provided an Array of Hashes' do
          before do
            @hash = { :title => 'Hash Article', :content => 'From Hash' }.freeze
            @return = @articles.replace([ @hash ])
          end

          it 'should return a Collection' do
            @return.should be_kind_of(DataMapper::Collection)
          end

          it 'should return self' do
            @return.should be_equal(@articles)
          end

          it 'should initialize a Resource' do
            @return.first.should be_kind_of(DataMapper::Resource)
          end

          it 'should be a new Resource' do
            @return.first.should be_new_record
          end

          it 'should be a Resource with attributes matching the Hash' do
            @return.first.attributes.only(*@hash.keys).should == @hash
          end
        end

        describe 'when provided a Resource belonging to another association' do
          before do
            @original = @other_articles
            @resource = @original.first
            @return = @articles.replace([ @resource ])
          end

          it 'should return a Collection' do
            @return.should be_kind_of(DataMapper::Collection)
          end

          it 'should return self' do
            @return.should be_equal(@articles)
          end

          it 'should relate the Resource to the Collection' do
            @resource.collection.should be_equal(@articles)
          end

          it_should_behave_like 'It can transfer a Resource from another association'
        end
      end

      describe '#unshift' do
        describe 'when provided a Resource belonging to another association' do
          before do
            @original = @other_articles
            @resource = @original.first
            @return = @articles.unshift(@resource)
          end

          it 'should return a Collection' do
            @return.should be_kind_of(DataMapper::Collection)
          end

          it 'should return self' do
            @return.should be_equal(@articles)
          end

          it_should_behave_like 'It can transfer a Resource from another association'
        end
      end

      describe '#update' do
        describe 'when the parent is not saved' do
          it 'should raise an exception' do
            author = Author.new(:name => 'Dan Kubb')
            lambda {
              author.sample_articles.update(:title => 'New Title')
            }.should raise_error(DataMapper::Associations::UnsavedParentError, 'The parent must be saved before mass-updating the association')
          end
        end
      end

      describe '#update!' do
        describe 'when the parent is not saved' do
          it 'should raise an exception' do
            author = Author.new(:name => 'Dan Kubb')
            lambda {
              author.sample_articles.update!(:title => 'New Title')
            }.should raise_error(DataMapper::Associations::UnsavedParentError, 'The parent must be saved before mass-updating the association without validation')
          end
        end
      end

      it 'should respond to #save' do
        @articles.should respond_to(:save)
      end

      describe '#save' do
        describe 'when Resources are not saved' do
          before do
            @articles = @author.articles
            @articles.build(:title => 'New Article', :content => 'New Article')
            @return = @articles.save
          end

          it 'should return true' do
            @return.should be_true
          end

          it 'should save each Resource' do
            @articles.each { |r| r.should_not be_new_record }
          end
        end

        describe 'when Resources have been orphaned' do
          before do
            @resources = @articles.entries
            @articles.replace([])
            @return = @articles.save
          end

          it 'should return true' do
            @return.should be_true
          end

          it 'should orphan each Resource' do
            @resources.each { |r| r.author.should be_nil }
          end

          it 'should save each orphaned Resource' do
            @resources.each { |r| r.reload.author.should be_nil }
          end
        end
      end
    end
  end
end
