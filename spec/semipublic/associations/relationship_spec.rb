require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'spec_helper'))

describe DataMapper::Associations::Relationship do
  describe '#inverse' do
    before :all do
      module ::Blog
        class Article
          include DataMapper::Resource

          property :title, String, :key => true

          has n, :comments
        end

        class Comment
          include DataMapper::Resource

          property :id,   Serial
          property :body, Text
        end
      end
    end

    def n
      1.0/0
    end

    describe 'with matching relationships' do
      before :all do
        @comments_relationship = Blog::Article.has(n, :comments)
        @article_relationship  = Blog::Comment.belongs_to(:article)

        # TODO: move this to spec/public/model/relationship_spec.rb
        @comments_relationship.child_repository_name.should be_nil
        @comments_relationship.parent_repository_name.should == :default

        # TODO: move this to spec/public/model/relationship_spec.rb
        @article_relationship.child_repository_name.should == :default
        @article_relationship.parent_repository_name.should be_nil
      end

      it 'should return the inverted relationships' do
        @comments_relationship.inverse.should equal(@article_relationship)
        @article_relationship.inverse.should  equal(@comments_relationship)
      end
    end

    describe 'with matching relationships where the child repository is not nil' do
      before :all do
        @comments_relationship = Blog::Article.has(n, :comments, :repository => :default)
        @article_relationship  = Blog::Comment.belongs_to(:article)

        # TODO: move this to spec/public/model/relationship_spec.rb
        @comments_relationship.child_repository_name.should == :default
        @comments_relationship.parent_repository_name.should == :default

        # TODO: move this to spec/public/model/relationship_spec.rb
        @article_relationship.child_repository_name.should == :default
        @article_relationship.parent_repository_name.should be_nil
      end

      it 'should return the inverted relationships' do
        @comments_relationship.inverse.should equal(@article_relationship)
        @article_relationship.inverse.should  equal(@comments_relationship)
      end
    end

    describe 'with matching relationships where the parent repository is not nil' do
      before :all do
        @comments_relationship = Blog::Article.has(n, :comments)
        @article_relationship  = Blog::Comment.belongs_to(:article, :repository => :default)

        # TODO: move this to spec/public/model/relationship_spec.rb
        @comments_relationship.child_repository_name.should be_nil
        @comments_relationship.parent_repository_name.should == :default

        # TODO: move this to spec/public/model/relationship_spec.rb
        @article_relationship.child_repository_name.should == :default
        @article_relationship.parent_repository_name.should == :default
      end

      it 'should return the inverted relationships' do
        @comments_relationship.inverse.should equal(@article_relationship)
        @article_relationship.inverse.should  equal(@comments_relationship)
      end
    end

    describe 'with no matching relationship', 'from the parent side' do
      before :all do
        @relationship = Blog::Article.has(n, :comments)

        @inverse = @relationship.inverse

        # after Relationship#inverse to ensure no match
        @expected = Blog::Comment.belongs_to(:article)
      end

      it 'should return a Relationship' do
        @inverse.should be_kind_of(DataMapper::Associations::Relationship)
      end

      it 'should return an inverted relationship' do
        @inverse.should == @expected
      end

      it 'should be an anonymous relationship' do
        @inverse.should_not equal(@expected)
      end

      it "should be have the relationship as it's inverse" do
        @inverse.inverse.should equal(@relationship)
      end
    end

    describe 'with no matching relationship', 'from the child side' do
      before :all do
        @relationship = Blog::Comment.belongs_to(:article)

        @inverse = @relationship.inverse

        # after Relationship#inverse to ensure no match
        @expected = Blog::Article.has(n, :comments)
      end

      it 'should return a Relationship' do
        @inverse.should be_kind_of(DataMapper::Associations::Relationship)
      end

      it 'should return an inverted relationship' do
        @inverse.should == @expected
      end

      it 'should be an anonymous relationship' do
        @inverse.should_not equal(@expected)
      end

      it "should be have the relationship as it's inverse" do
        @inverse.inverse.should equal(@relationship)
      end
    end
  end
end
