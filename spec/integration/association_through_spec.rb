require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

if ADAPTER
  describe 'through-associations' do
    before :all do
      repository(ADAPTER) do
        class Post
          include DataMapper::Resource
          def self.default_repository_name
            ADAPTER
          end

          property :id, Integer, :serial => true
          property :title, String

          has n, :taggings
          has n, :tags => :taggings

          has n, :relationships
          has n, {:related_posts => :relationships}, :class_name => "Post"
        end

        class Tag
          include DataMapper::Resource
          def self.default_repository_name
            ADAPTER
          end

          property :id, Integer, :serial => true
          property :title, String

          has n, :taggings
          has n, :posts => :taggings
        end

        class Tagging
          include DataMapper::Resource
          def self.default_repository_name
            ADAPTER
          end

          property :id, Integer, :serial => true
          belongs_to :post
          belongs_to :tag
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
        post.save
        another_post.save

        crappy = Tagging.new
        post.taggings << crappy
        crappy.save

        crap = Tag.create(:title => "crap")
        crap.taggings << crappy
        crappy.save

        goody = Tagging.new
        another_post.taggings << goody
        goody.save

        good = Tag.create(:title => "good")
        good.taggings << goody

        relation = Relationship.new(:related_post => another_post)
        post.relationships << relation
        relation.save
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
  end
end
