require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

describe DataMapper::Resource, "Transactions" do

  before do
    Object.send(:remove_const, :User) if defined?(User)
    class User
      include DataMapper::Resource

      property :name,        String, :key => true
      property :age,         Integer
      property :description, Text

      has n, :comments
    end

    Object.send(:remove_const, :Comment) if defined?(Comment)
    class Comment
      include DataMapper::Resource

      property :id,   Serial
      property :body, Text

      belongs_to :user
    end
  end

  supported_by :postgres, :mysql do
    before(:each) do
      # --- Temporary private api use to get around rspec limitations ---
      repository(:default) do
        transaction = DataMapper::Transaction.new(repository)
        transaction.begin
        repository.adapter.push_transaction(transaction)
      end

      @model       = User
      @child_model = Comment
      @user        = @model.create(:name => 'dbussink', :age => 25, :description => "Test")
    end

    after do
      repository = repository(:default)
      while repository.adapter.current_transaction
        repository.adapter.current_transaction.rollback
        repository.adapter.pop_transaction
      end
    end

    it_should_behave_like 'A public Resource'

  end

  supported_by :postgres, :mysql do

    describe "#transaction" do

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

      it "should not mark persisted resources as new records" do
        User.transaction do
          User.create(:name => "carllerche").should_not be_new_record
        end
      end

      it "should rollback when an error is thrown in a transaction" do
        lambda {
          User.transaction do
            User.create(:name => "carllerche")
            raise "I love coffee"
          end
        }.should raise_error("I love coffee")
        User.first.should be_nil
      end

    end

  end

end
