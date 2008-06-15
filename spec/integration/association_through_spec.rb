require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

if ADAPTER
  describe 'through-associations' do
    before :all do
      repository(ADAPTER) do
        
        class Tag
          include DataMapper::Resource
          def self.default_repository_name
            ADAPTER
          end

          property :id,     Integer, :serial => true
          property :title,  String
          property :voided, Boolean, :default => false

          has n, :taggings

          has n, :relationships
          has n, :related_posts, :through => :relationships, :class_name => 'Post'

          has n, :posts, :through => :taggings
        end
        
        class Tagging
          include DataMapper::Resource
          def self.default_repository_name
            ADAPTER
          end

          property :id, Integer, :serial => true
          property :title, String

          belongs_to :post
          belongs_to :tag
        end
        
        class Post
          include DataMapper::Resource
          def self.default_repository_name
            ADAPTER
          end

          property :id, Integer, :serial => true
          property :title, String

          has n, :taggings
          has n, :tags, :through => :taggings

          has n, :relationships
          has n, :related_posts,
                 :through    => :relationships, 
                 :class_name => "Post"
          
          has n,  :void_tags, 
                  :through => :taggings, 
                  :class_name => "Tag",
                  :remote_relationship_name => :tag,
                  Post.taggings.tag.voided => true
        end

        class Relationship
          include DataMapper::Resource
          def self.default_repository_name
            ADAPTER
          end

          property :id, Integer, :serial => true
          belongs_to :post
          belongs_to :related_post, :class_name => "Post"
        end        

        [Post, Tag, Tagging, Relationship].each do |descendant|
          descendant.auto_migrate!(ADAPTER)
        end

        post = Post.create(:title => "Entry")
        another_post = Post.create(:title => "Another")

        crappy = Tagging.new
        post.taggings << crappy
        post.save

        crap = Tag.create(:title => "crap")
        crap.taggings << crappy
        crap.save
        
        crappier = Tagging.new
        post.taggings << crappier
        post.save
        
        crapz = Tag.create(:title => "crapz", :voided => true)
        crapz.taggings << crappier
        crapz.save

        goody = Tagging.new
        another_post.taggings << goody
        another_post.save

        good = Tag.create(:title => "good")
        good.taggings << goody
        good.save

        relation = Relationship.new(:related_post => another_post)
        post.relationships << relation
        post.save
      end
    end

    it 'should return the right children for has n => belongs_to relationships' do
      Post.first.tags.select do |tag|
        tag.title == 'crap'
      end.size.should == 1
    end

    it 'should return the right children for has n => belongs_to self-referential relationships' do
      Post.first.related_posts.select do |post|
        post.title == 'Another'
      end.size.should == 1
    end

    it 'should handle all()' do
      related_posts = Post.first.related_posts
      related_posts.all.object_id.should == related_posts.object_id
      related_posts.all(:id => 2).first.should == Post.get!(2)
    end

    it 'should handle first()' do
      post = Post.get!(2)
      related_posts = Post.first.related_posts
      related_posts.first.should == post
      related_posts.first(10).should == [ post ]
      related_posts.first(:id => 2).should == post
      related_posts.first(10, :id => 2).map { |r| r.id }.should == [ post.id ]
    end

    it 'should proxy object should be frozen' do
      Post.first.related_posts.should be_frozen
    end
    
    it "should respect tagging with conditions" do
      post = Post.get(1)
      post.tags.size
      post.tags.select{|t| t.voided == true}.size.should == 1
      post.void_tags.size.should == 1
      post.void_tags.all?{|t| t.voided == true}.should be_true      
    end
  end
end
