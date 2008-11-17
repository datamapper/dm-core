share_examples_for 'A semipublic Resource' do
  before do
    %w[ @model @user @child_model ].each do |ivar|
      raise "+#{ivar}+ should be defined in before block" unless instance_variable_get(ivar)
    end
  end

  it { @user.should respond_to(:attribute_get) }

  describe '#attribute_get' do

    it { @user.attribute_get(:name).should == 'dbussink' }

  end

  it { @user.should respond_to(:attribute_set) }

  describe '#attribute_set' do

    before { @user.attribute_set(:name, 'dkubb') }

    it { @user.name.should == 'dkubb' }

  end

  it { @user.should respond_to(:dirty?) }

  describe '#dirty' do

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

  describe '#attribute_dirty' do

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

end
