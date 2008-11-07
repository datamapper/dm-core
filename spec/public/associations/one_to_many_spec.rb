require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'spec_helper'))
require SPEC_ROOT + 'lib/collection_shared_spec'

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


# TODO: test loaded and unloaded behavior

describe DataMapper::Associations::OneToMany::Proxy do

  # define the model prior to with_adapters
  before do
    Object.send(:remove_const, :Author) if defined?(Author)
    class Author
      include DataMapper::Resource

      property :id,   Serial
      property :name, String

      # TODO: move conditions down to before block once author.articles(query)
      # returns a OneToMany::Proxy object (and not Collection as it does now)
      has n, :sample_articles, :title => 'Sample Article', :class_name => 'Article'
      has n, :other_articles,  :title => 'Other Article',  :class_name => 'Article'
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

    after do
      @articles.dup.destroy!
      @author.destroy
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
  end
end
