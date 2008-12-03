require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

describe DataMapper::Resource do
  before do
    class User
      include DataMapper::Resource

      property :name,        String, :key => true
      property :age,         Integer
      property :description, Text
      property :admin,       Boolean, :default => false, :accessor => :private

      has n, :comments
    end

    class Author < User; end

    class Article
      include DataMapper::Resource

      property :id,   Serial
      property :body, Text

      has n, :paragraphs
    end

    class Comment
      include DataMapper::Resource

      property :id,   Serial
      property :body, Text

      belongs_to :user
    end

    class Paragraph
      include DataMapper::Resource

      property :id,   Serial
      property :text, String

      belongs_to :article
    end
  end

  after do
    # FIXME: should not need to clear STI models explicitly
    Object.send(:remove_const, :Author) if defined?(Author)
  end

  supported_by :all do
    before do
      @model       = User
      @child_model = Comment
      @user        = @model.create(:name => 'dbussink', :age => 25, :description => "Test")
    end

    it_should_behave_like 'A public Resource'
  end
end
