require 'spec_helper'

describe 'Many to Many Associations' do
  before :all do
    module ::Blog
      class Article
        include DataMapper::Resource

        property :title, String, :key => true
        property :body,  Text,   :required => true

        has n, :without_default_join,       'WithoutDefault'
        has n, :with_default_join,          'WithDefault'
        has n, :with_default_callable_join, 'WithDefaultCallable'
      end

      class Author
        include DataMapper::Resource

        property :name, String, :key => true

        has n, :without_default_join,       'WithoutDefault'
        has n, :with_default_join,          'WithDefault'
        has n, :with_default_callable_join, 'WithDefaultCallable'

        has n, :without_default,       'Article', :through => :without_default_join,       :via => :article
        has n, :with_default,          'Article', :through => :with_default_join,          :via => :article
        has n, :with_default_callable, 'Article', :through => :with_default_callable_join, :via => :article
      end

      class WithoutDefault
        include DataMapper::Resource

        belongs_to :article, :key => true
        belongs_to :author,  :key => true
      end

      class WithDefault
        include DataMapper::Resource

        belongs_to :article, :key => true
        belongs_to :author,  :key => true
      end

      class WithDefaultCallable
        include DataMapper::Resource

        belongs_to :article, :key => true
        belongs_to :author,  :key => true
      end
    end


    @article_model = Blog::Article
    @author_model  = Blog::Author

    n = @article_model.n

    @default_value          = [ @author_model.new(:name => 'Dan Kubb') ]
    @default_value_callable = [ @author_model.new(:name => 'John Doe') ]

    @subject_without_default       = @article_model.has(n, :without_default,       'Author', :through => :without_default_join,       :via => :author)
    @subject_with_default          = @article_model.has(n, :with_default,          'Author', :through => :with_default_join,          :via => :author, :default => @default_value)
    @subject_with_default_callable = @article_model.has(n, :with_default_callable, 'Author', :through => :with_default_callable_join, :via => :author, :default => lambda { |resource, relationship| @default_value_callable })

    DataMapper.finalize
  end

  supported_by :all do
    before :all do
      @no_join = defined?(DataMapper::Adapters::InMemoryAdapter) && @adapter.kind_of?(DataMapper::Adapters::InMemoryAdapter) ||
                 defined?(DataMapper::Adapters::YamlAdapter)     && @adapter.kind_of?(DataMapper::Adapters::YamlAdapter)
    end

    before do
      pending if @no_join
    end

    before :all do
      @default_value.each { |resource| resource.save }
      @default_value_callable.each { |resource| resource.save }
    end

    describe 'acts like a subject' do
      before do
        @resource = @article_model.new(:title => 'DataMapper Rocks!', :body => 'TSIA')
      end

      it_should_behave_like 'A semipublic Subject'
    end
  end
end
