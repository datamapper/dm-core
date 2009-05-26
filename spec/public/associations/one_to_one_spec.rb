require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'spec_helper'))

describe 'One to One Associations' do
  before :all do
    class ::User
      include DataMapper::Resource

      property :name,        String, :key => true
      property :age,         Integer
      property :summary,     Text
      property :description, Text
      property :admin,       Boolean, :accessor => :private

      belongs_to :referrer, :model => self, :nullable => true
      has 1, :comment

      # TODO: remove this after Relationship#inverse can dynamically
      # create an inverse relationship when no perfect match can be found
      has n, :referree, :model => self, :child_key => [ :referrer_name ]
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

  supported_by :all do
    before :all do
      user    = @model.create(:name => 'dbussink', :age => 25, :description => 'Test')
      comment = @child_model.create(:body => 'Cool spec', :user => user)

      @comment = @child_model.get(*comment.key)
      @user    = @comment.user
    end

    it_should_behave_like 'A public Resource'
    it_should_behave_like 'A Resource supporting Strategic Eager Loading'
  end
end

describe 'One to One Through Associations' do
  before :all do
    class ::Referral
      include DataMapper::Resource

      property :referrer_name, String, :key => true
      property :referree_name, String, :key => true

      belongs_to :referrer, :model => 'User', :child_key => [ :referrer_name ], :nullable => true
      belongs_to :referree, :model => 'User', :child_key => [ :referree_name ], :nullable => true
    end

    class ::User
      include DataMapper::Resource

      property :name,        String, :key => true
      property :age,         Integer
      property :summary,     Text
      property :description, Text
      property :admin,       Boolean, :accessor => :private

      has 1, :referral_from, :model => 'Referral', :child_key => [ :referrer_name ]
      has 1, :referral_to,   :model => 'Referral', :child_key => [ :referree_name ]

      has 1, :referrer, :through => :referral_from, :model => self
      has 1, :referree, :through => :referral_to,   :model => self
      has 1, :comment,  :through => Resource
    end

    class ::Author < User; end

    class ::Comment
      include DataMapper::Resource

      property :id,   Serial
      property :body, Text

      has 1, :user, :through => Resource
    end

    class ::Article
      include DataMapper::Resource

      property :id,   Serial
      property :body, Text

      has 1, :paragraph, :through => Resource
    end

    class ::Paragraph
      include DataMapper::Resource

      property :id,   Serial
      property :text, String

      has 1, :article, :through => Resource
    end

    @model       = User
    @child_model = Comment
  end

  supported_by :all do
    before :all do
      user    = @model.create(:name => 'dbussink', :age => 25, :description => 'Test')
      comment = @child_model.create(:body => 'Cool spec', :user => user)

      @comment = @child_model.get(*comment.key)
      @user    = @comment.user
    end

    it_should_behave_like 'A public Resource'

    # TODO: make this pass
    #it_should_behave_like 'A Resource supporting Strategic Eager Loading'
  end
end
