share_examples_for 'A semipublic Resource' do
  before do
    %w[ @model @user ].each do |ivar|
      raise "+#{ivar}+ should be defined in before block" unless instance_variable_get(ivar)
    end
  end

  it { @user.should respond_to(:dirty?) }

  describe '#dirty?' do

    describe 'on a non-dirty record' do

      it { @user.should_not be_dirty }

    end

    describe 'on a dirty record' do

      before { @user.age = 100 }

      it { @user.should be_dirty }

    end

    describe 'on a new record' do

      before { @user = User.new }

      it { @user.should be_dirty }

    end

  end

  it { @user.should respond_to(:attribute_dirty?) }

  describe '#attribute_dirty?' do

    describe 'on a non-dirty record' do

      it { @user.attribute_dirty?(:age).should be_false }

    end

    describe 'on a dirty record' do

      before { @user.age = 100 }

      it { @user.attribute_dirty?(:age).should be_true }

    end

    describe 'on a new record' do

      before { @user = User.new }

      it { @user.attribute_dirty?(:age).should be_true }

    end

  end

  it { @user.should respond_to(:hash) }

  describe '#hash' do

    describe 'on two equal unsaved objects' do

      before do
        @user1 = User.new(:name => 'dbussink', :age => 50)
        @user2 = User.new(:name => 'dbussink', :age => 50)
      end

      it { @user1.hash.should eql(@user2.hash) }

    end

    describe 'on two equal objects with a different object id' do

      before { @user2 = User.get("dbussink") }

      it { @user.object_id.should_not eql(@user2.object_id) }

      it { @user.hash.should eql(@user2.hash) }

    end


    describe 'on two different objects of the same type' do

      before { @user2 = User.create(:name => "dkubb", :age => 25) }

      it { @user.hash.should_not eql(@user2.hash) }

    end

    describe 'on two different types with the same key' do

      before { @user2 = Clone.create(:name => "dbussink", :age => 25) }

      it { @user.hash.should_not eql(@user2.hash) }

    end

  end

  it { @user.should respond_to(:repository) }

  describe "#repository" do

    before(:each) do
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

        repository(:alternate) { User.get("carl") }.repository.should == repository(:alternate)
      end
    end

  end

end
