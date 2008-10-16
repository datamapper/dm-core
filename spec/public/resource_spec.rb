require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

describe DataMapper::Resource do

    before(:each) do
      Object.send(:remove_const, :User) if defined?(User)
      class User
        include DataMapper::Resource

        property :id,   Integer, :key => true
        property :name, String
      end

      # This is a special class that needs to be an exact copy of User
      Object.send(:remove_const, :Clone) if defined?(Clone)
      class Clone
        include DataMapper::Resource

        property :id,   Integer, :key => true
        property :name, String
      end
    end

  with_adapters do

    describe "#eql?" do

      it "should be true when they are the same objects" do
        user = User.new
        user.should be_eql(user)
      end

      it "should be false when they are instances of different classes" do
        User.new(:name => "John").should_not    be_eql(Clone.new(:name => "John"))
        User.create(:name => "John").should_not be_eql(Clone.create(:name => "John"))
      end

      it "should be true when they are instances from the same repository, the keys are the same, and properties are the same" do
        user = User.create(:name => "Bill", :id => 1)
        user.should be_eql(User.get(1))
      end

      it "should be true when they are instances from the same repository, the keys are the same, but the attributes differ" do
        user = User.create(:name => "Bill", :id => 1)
        user.name = "John"
        user.should be_eql(User.get(1))
      end

      with_alternate do
        it "should be true when they are instances from different repositories, but the keys and attributes are the same" do
          pending
          user  = User.create(:name => "Bill", :id => 5)
          other = repository(:alternate) { User.create(:name => "Bill", :id => 5) }
          user.should be_eql(other)
        end
      end

      it "should be true when they are different " do

      end

    end

  end

end
