require 'spec_helper'

describe DataMapper::Resource do
  before :all do
    module ::Blog
      class User
        include DataMapper::Resource

        property :name,        String, :key => true
        property :age,         Integer
        property :summary,     Text
        property :description, Text
        property :admin,       Boolean, :accessor => :private

        belongs_to :parent, self, :required => false
        has n, :children, self, :inverse => :parent

        belongs_to :referrer, self, :required => false
        has n, :comments

        # FIXME: figure out a different approach than stubbing things out
        def comment=(*)
          # do nothing with comment
        end
      end

      class Author < User; end

      class Comment
        include DataMapper::Resource

        property :id,   Serial
        property :body, Text

        belongs_to :user
      end

      class Article
        include DataMapper::Resource

        property :id,   Serial
        property :body, Text

        has n, :paragraphs
      end

      class Paragraph
        include DataMapper::Resource

        property :id,   Serial
        property :text, String

        belongs_to :article
      end
    end

    class ::Default
      include DataMapper::Resource

      property :name, String, :key => true, :default => 'a default value'
    end
    DataMapper.finalize

    @user_model      = Blog::User
    @author_model    = Blog::Author
    @comment_model   = Blog::Comment
    @article_model   = Blog::Article
    @paragraph_model = Blog::Paragraph
  end

  supported_by :all do
    before :all do
      user = @user_model.create(:name => 'dbussink', :age => 25, :description => 'Test')

      @user = @user_model.get(*user.key)
    end

    it_should_behave_like 'A public Resource'
    it_should_behave_like 'A Resource supporting Strategic Eager Loading'

    it 'A resource should respond to raise_on_save_failure' do
      @user.should respond_to(:raise_on_save_failure)
    end

    describe '#raise_on_save_failure' do
      after do
        # reset to the default value
        reset_raise_on_save_failure(@user_model)
        reset_raise_on_save_failure(@user)
      end

      subject { @user.raise_on_save_failure }

      describe 'when model.raise_on_save_failure has not been set' do
        it { should be(false) }
      end

      describe 'when model.raise_on_save_failure has been set to true' do
        before do
          @user_model.raise_on_save_failure = true
        end

        it { should be(true) }
      end

      describe 'when resource.raise_on_save_failure has been set to true' do
        before do
          @user.raise_on_save_failure = true
        end

        it { should be(true) }
      end
    end

    it 'A model should respond to raise_on_save_failure=' do
      @user_model.should respond_to(:raise_on_save_failure=)
    end

    describe '#raise_on_save_failure=' do
      after do
        # reset to the default value
        @user_model.raise_on_save_failure = false
      end

      subject { @user_model.raise_on_save_failure = @value }

      describe 'with a true value' do
        before do
          @value = true
        end

        it { should be(true) }

        it 'should set raise_on_save_failure' do
          method(:subject).should change {
            @user_model.raise_on_save_failure
          }.from(false).to(true)
        end
      end

      describe 'with a false value' do
        before do
          @value = false
        end

        it { should be(false) }

        it 'should set raise_on_save_failure' do
          method(:subject).should_not change {
            @user_model.raise_on_save_failure
          }
        end
      end
    end

    [ :save, :save! ].each do |method|
      describe "##{method}" do
        subject { @user.__send__(method) }

        describe 'when raise_on_save_failure is true' do
          before do
            @user.raise_on_save_failure = true
          end

          describe 'and it is a savable resource' do
            it { should be(true) }
          end

          describe 'and it is an invalid resource' do
            before do
              @user.name = nil  # name is required
            end

            it 'should raise an exception' do
              method(:subject).should raise_error(DataMapper::SaveFailureError, "Blog::User##{method} returned false, Blog::User was not saved") { |error|
                error.resource.should equal(@user)
              }
            end
          end
        end
      end
    end

    [ :update, :update! ].each do |method|
      describe 'with attributes where one is a foreign key' do
        before :all do
          rescue_if @skip do
            @dkubb = @user.referrer = @user_model.create(:name => 'dkubb', :age => 33)
            @user.save
            @user = @user_model.get(*@user.key)
            @user.referrer.should == @dkubb

            @solnic = @user_model.create(:name => 'solnic', :age => 28)

            @attributes = {}

            relationship = @user_model.relationships[:referrer]
            relationship.child_key.to_a.each_with_index do |k, i|
              @attributes[k.name] = relationship.parent_key.to_a[i].get(@solnic)
            end

            @return = @user.__send__(method, @attributes)
          end
        end

        it 'should return true' do
          @return.should be(true)
        end

        it 'should update attributes of Resource' do
          @attributes.each { |key, value| @user.__send__(key).should == value }
        end

        it 'should persist the changes' do
          resource = @user_model.get(*@user.key)
          @attributes.each { |key, value| resource.__send__(key).should == value }
        end

        it 'should return correct parent' do
          resource = @user_model.get(*@user.key)
          resource.referrer.should == @solnic
        end
      end
    end
  end
end
