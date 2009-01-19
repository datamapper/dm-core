require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'spec_helper'))

describe 'One to One Associations' do
  before do
    class ::User
      include DataMapper::Resource

      property :name,        String, :key => true
      property :age,         Integer
      property :description, Text
      property :admin,       Boolean, :accessor => :private

      belongs_to :referrer, :class => self, :child_key => [ :referrer_name ]
      has 1, :comment
    end

    class ::Author < User; end

    class ::Comment
      include DataMapper::Resource

      property :id,   Serial
      property :body, Text

      belongs_to :user
    end

    class ::Article
      include DataMapper::Resource

      property :id,   Serial
      property :body, Text

      has 1, :paragraph
    end

    class ::Paragraph
      include DataMapper::Resource

      property :id,   Serial
      property :text, String

      belongs_to :article
    end

    @model       = User
    @child_model = Comment
  end

  after do
    # FIXME: should not need to clear STI models explicitly
    Object.send(:remove_const, :Author) if defined?(Author)
  end

  supported_by :all do
    before do
      user    = @model.create(:name => 'dbussink', :age => 25, :description => 'Test')
      comment = @child_model.create(:body => 'Cool spec', :user => user)

      @comment     = @child_model.get(*comment.key)
      @user        = @comment.user
    end

    it_should_behave_like 'A public Resource'
  end
end
