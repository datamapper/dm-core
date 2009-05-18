require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

describe DataMapper::Resource, 'Transactions' do
  before :all do
    class ::User
      include DataMapper::Resource

      property :name,        String, :key => true
      property :age,         Integer
      property :summary,     Text
      property :description, Text
      property :admin,       Boolean, :accessor => :private

      belongs_to :referrer, :model => self
      has n, :comments
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

      has n, :paragraphs
    end

    class ::Paragraph
      include DataMapper::Resource

      property :id,   Serial
      property :text, String

      belongs_to :article
    end
  end

  supported_by :postgres, :mysql do
    before :all do
      @model       = User
      @child_model = Comment
      @user        = @model.create(:name => 'dbussink', :age => 25, :description => "Test")
    end

    before do
      # --- Temporary private api use to get around rspec limitations ---
      @repository.scope do |r|
        transaction = DataMapper::Transaction.new(r)
        transaction.begin
        r.adapter.push_transaction(transaction)
      end
    end

    after do
      while @repository.adapter.current_transaction
        @repository.adapter.pop_transaction.rollback
      end
    end

    it_should_behave_like 'A public Resource'

  end

  supported_by :postgres, :mysql do

    describe "#transaction" do

      before do
        User.all.destroy!
      end

      it "should have access to resources presisted before the transaction" do
        User.create(:name => "carllerche")
        User.transaction do
          User.first.name.should == "carllerche"
        end
      end

      it "should have access to resources persisted in the transaction" do
        User.transaction do
          User.create(:name => "carllerche")
          User.first.name.should == "carllerche"
        end
      end

      it "should not mark saved resources as new records" do
        User.transaction do
          User.create(:name => "carllerche").should_not be_new
        end
      end

      it "should rollback when an error is thrown in a transaction" do
        User.all.should have(0).entries
        lambda {
          User.transaction do
            User.create(:name => "carllerche")
            raise "I love coffee"
          end
        }.should raise_error("I love coffee")
        User.all.should have(0).entries
      end

      it "should return the last statement in the transaction block" do
        pending 'Transaction is refactored not to use the contructor directly' do
          User.transaction { 1 }.should == 1
        end
      end

    end

  end

end
