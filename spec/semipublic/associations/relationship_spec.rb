require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'spec_helper'))

describe DataMapper::Associations::Relationship do
  before :all do
    module ::Blog
      class Article
        include DataMapper::Resource

        property :title, String, :key => true
      end

      class Comment
        include DataMapper::Resource

        property :id,   Serial
        property :body, Text
      end
    end

    @article_model = Blog::Article
    @comment_model = Blog::Comment
  end

  def n
    1.0/0
  end

  describe '#inverse' do
    describe 'with matching relationships' do
      before :all do
        @comments_relationship = @article_model.has(n, :comments)
        @article_relationship  = @comment_model.belongs_to(:article)

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
        @comments_relationship = @article_model.has(n, :comments, :repository => :default)
        @article_relationship  = @comment_model.belongs_to(:article)

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
        @comments_relationship = @article_model.has(n, :comments)
        @article_relationship  = @comment_model.belongs_to(:article, :repository => :default)

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
        # added to force OneToMany::Relationship#inverse to consider the
        # child_key differences
        @comment_model.belongs_to(:other_article, @article_model, :child_key => [ :other_article_id ])

        @relationship = @article_model.has(n, :comments)

        @inverse = @relationship.inverse

        # after Relationship#inverse to ensure no match
        @expected = @comment_model.belongs_to(:article)
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

      it 'should have a source repository equal to the target repository of the relationship' do
        @inverse.source_repository_name.should == @relationship.target_repository_name
      end

      it "should be have the relationship as it's inverse" do
        @inverse.inverse.should equal(@relationship)
      end
    end

    describe 'with no matching relationship', 'from the child side' do
      before :all do
        @relationship = @comment_model.belongs_to(:article)

        @inverse = @relationship.inverse

        # after Relationship#inverse to ensure no match
        @expected = @article_model.has(n, :comments)
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

      it 'should have a source repository equal to the target repository of the relationship' do
        @inverse.source_repository_name.should == @relationship.target_repository_name
      end

      it "should be have the relationship as it's inverse" do
        @inverse.inverse.should equal(@relationship)
      end
    end
  end

  describe '#valid?' do
    before :all do
      @relationship = @article_model.has(n, :comments)
    end

    supported_by :all do
      describe 'with valid resource' do
        before :all do
          @article  = @article_model.create(:title => 'Relationships in DataMapper')
          @resource = @article.comments.create
        end

        it 'should return true' do
          @relationship.valid?(@resource).should be_true
        end
      end

      describe 'with a resource of the wrong class' do
        before :all do
          @resource  = @article_model.new
        end

        it 'should return false' do
          @relationship.valid?(@resource).should be_false
        end
      end

      describe 'with a resource without a valid parent' do
        before :all do
          @resource = @comment_model.new
        end

        it 'should return false' do
          @relationship.valid?(@resource).should be_false
        end
      end
    end
  end
end
