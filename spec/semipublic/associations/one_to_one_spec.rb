require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'spec_helper'))

describe 'One to One Associations' do
  before :all do
    module ::Blog
      class Article
        include DataMapper::Resource

        property :title, String, :key => true
        property :body,  Text,   :required => true
      end
    end

    @article_model = Blog::Article
  end

  supported_by :all do
    before :all do
      @article = @article_model.new(:title => 'DataMapper Rocks!', :body => 'TSIA')
    end

    describe 'acts like a subject' do
      before do
        @subject_without_default       = @article_model.has(1, :without_default,       @article_model)
        @subject_with_default          = @article_model.has(1, :with_default,          @article_model, :default => @article)
        @subject_with_default_callable = @article_model.has(1, :with_default_callable, @article_model, :default => lambda { |resource, relationship| @article })

        @subject_without_default_value       = nil
        @subject_with_default_value          = @article
        @subject_with_default_callable_value = @article

        @resource = @article_model.new
      end

      it_should_behave_like 'A semipublic Subject'
    end
  end
end
