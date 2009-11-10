require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

describe DataMapper::Resource, 'Transactions' do
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

    @user_model      = Blog::User
    @author_model    = Blog::Author
    @comment_model   = Blog::Comment
    @article_model   = Blog::Article
    @paragraph_model = Blog::Paragraph
  end

  supported_by :postgres, :mysql, :sqlite3, :oracle, :sqlserver do
    before :all do
      user = @user_model.create(:name => 'dbussink', :age => 25, :description => 'Test')

      @user = @user_model.get(*user.key)
    end

    before do
      # --- Temporary private api use to get around rspec limitations ---
      @repository.scope do |repository|
        transaction = DataMapper::Transaction.new(repository)
        transaction.begin
        repository.adapter.push_transaction(transaction)
      end
    end

    after do
      while @repository.adapter.current_transaction
        @repository.adapter.pop_transaction.rollback
      end
    end

    it_should_behave_like 'A public Resource'
    it_should_behave_like 'A Resource supporting Strategic Eager Loading'
  end

  supported_by :postgres, :mysql, :sqlite3, :oracle, :sqlserver do
    describe '#transaction' do
      before do
        @user_model.all.destroy!
      end

      it 'should have access to resources presisted before the transaction' do
        @user_model.create(:name => 'carllerche')
        @user_model.transaction do
          @user_model.first.name.should == 'carllerche'
        end
      end

      it 'should have access to resources persisted in the transaction' do
        @user_model.transaction do
          @user_model.create(:name => 'carllerche')
          @user_model.first.name.should == 'carllerche'
        end
      end

      it 'should not mark saved resources as new records' do
        @user_model.transaction do
          @user_model.create(:name => 'carllerche').should_not be_new
        end
      end

      it 'should rollback when an error is thrown in a transaction' do
        @user_model.all.should have(0).entries
        lambda {
          @user_model.transaction do
            @user_model.create(:name => 'carllerche')
            raise 'I love coffee'
          end
        }.should raise_error('I love coffee')
        @user_model.all.should have(0).entries
      end

      it 'should close the transaction if return is called within the closure' do
        @txn = nil

        def doit
          @user_model.transaction do
            @txn = Thread.current[:dm_transactions].last
            return
          end
        end
        doit

        @txn.instance_variable_get(:@state).should == :commit
        @txn = nil
      end

      it 'should return the last statement in the transaction block' do
        @user_model.transaction { 1 }.should == 1
      end
    end
  end
end
