require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

describe DataMapper::Resource do

    before(:each) do
      Object.send(:remove_const, :User) if defined?(User)
      class User
        include DataMapper::Resource

        property :name, String, :key => true
        property :age,  Integer
      end

      # This is a special class that needs to be an exact copy of User
      Object.send(:remove_const, :Clone) if defined?(Clone)
      class Clone
        include DataMapper::Resource

        property :name, String, :key => true
        property :age,  Integer
      end
    end

  supported_by :all do

    # All methods that provide equality comparisons of some sort
    # should satisfy the following specs.
    def self.it_should_provide_equality(method)

      it "should be true when they are the same objects" do
        user = User.new
        user.send(method, user).should be_true
      end

      it "should be true when all the attributes are the same" do
        user = User.create(:name => "Bill", :age => 1)
        user.send(method, User.get("Bill")).should be_true
      end

      it "should be true when all the attributes are the same even if one has not been persisted" do
        user = User.create(:name => "Bill", :age => 1)
        user.send(method, User.new(:name => "Bill", :age => 1)).should be_true
      end

      it "should not be true when the attributes differ even if the keys are the same" do
        user = User.create(:name => "Bill", :age => 10)
        user.age = 20
        user.send(method, User.get("Bill")).should be_false
      end

      with_alternate_adapter do
        it "should be true when they are instances from different repositories, but the keys and attributes are the same" do
          user  = User.create(:name => "Bill", :age => 5)
          other = repository(:alternate) { User.create(:name => "Bill", :age => 5) }
          user.send(method, other).should be_true
        end
      end

    end

    describe "#eql?" do

      it_should_provide_equality :eql?

      # --- Only for #eql? ---

      it "should be false when they are instances of different classes" do
        User.new(:name => "John", :age => 10).should_not    be_eql(Clone.new(:name => "John", :age => 10))
        User.create(:name => "John", :age => 10).should_not be_eql(Clone.create(:name => "John", :age => 10))
      end

    end

    describe "#==" do

      it_should_provide_equality :==

      it "should be true when they are instances of different classes and the attributes are the same" do
        pending "FIX ME" do
          User.new(:name => "John", :age => 10).should    == Clone.new(:name => "John", :age => 10)
          User.create(:name => "John", :age => 10).should == Clone.create(:name => "John", :age => 10)
        end
      end

      it "should not be true if any attribute differs" do
        User.new(:name => "John", :age => 10).should_not == Clone.new(:name => "John", :age => 20)
      end

    end

    describe "#===" do

      it_should_provide_equality :===

      it "should be true when they are instances of different classes and the attributes are the same" do
        pending "FIX ME" do
          User.new(:name => "John", :age => 10).should    === Clone.new(:name => "John", :age => 10)
          User.create(:name => "John", :age => 10).should === Clone.create(:name => "John", :age => 10)
        end
      end

      it "should not be true if any attribute differs" do
        User.new(:name => "John", :age => 10).should_not === Clone.new(:name => "John", :age => 20)
      end

    end

    describe "#repository" do

      before(:each) do
        Object.send(:remove_const, :Statistic) if defined?(Statistic)
        class Statistic
          include DataMapper::Resource

          def self.default_repository_name ; :alternate ; end

          property :id,    Serial
          property :name,  String
          property :value, Integer
        end
      end

      with_alternate_adapter do
        it "should return the default adapter when nothing is specified" do
          User.create(:name => "carl").repository.should == repository(:default)
          User.new.repository.should                     == repository(:default)
          User.get("carl").repository.should             == repository(:default)
        end

        it "should return the default repository for the model" do
          statistic = Statistic.create(:name => "visits", :value => 2)
          statistic.repository.should        == repository(:alternate)
          Statistic.new.repository.should    == repository(:alternate)
          Statistic.get(1).repository.should == repository(:alternate)
        end

        it "should return the repository defined by the current context" do
          repository(:alternate) do
            User.new.repository.should                     == repository(:alternate)
            User.create(:name => "carl").repository.should == repository(:alternate)
            User.get("carl").repository.should             == repository(:alternate)
          end
        end
      end

    end

    describe "#id" do

      it "should return the value of the id property if there is one"
      it "should return the value of the key if it is a single column key"
      it "should return nil if the key is a multi column key"
      it "should return nil if there is no key"

    end

  end

end
