require 'spec_helper'

describe 'SEL', 'with STI subclasses' do
  before :all do
    module ::Blog
      class Author
        include DataMapper::Resource

        property :id,   Serial
        property :name, String

        has n, :messages
      end

      class Message
        include DataMapper::Resource

        property :id,    Serial
        property :type,  Discriminator
        property :title, String, :required => true

        belongs_to :author
      end

      class Article < Message; end
      class Comment < Message; end
    end

    DataMapper.finalize

    @author_model  = Blog::Author
    @message_model = Blog::Message
    @article_model = Blog::Article
    @comment_model = Blog::Comment
  end

  supported_by :all do
    before :all do
      author1 = @author_model.create(:name => 'Dan Kubb')
      author2 = @author_model.create(:name => 'Sindre Aarsaether')

      @article_model.create(:title => 'SEL',               :author => author1)
      @article_model.create(:title => 'STI',               :author => author1)
      @comment_model.create(:title => 'SEL and STI error', :author => author2)
    end

    it 'should allow STI loading of mixed relationships' do
      lambda {
        @message_model.all.each { |message| message.author }
      }.should_not raise_error(ArgumentError)
    end
  end
end
