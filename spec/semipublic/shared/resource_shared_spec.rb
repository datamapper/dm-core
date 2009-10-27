share_examples_for 'A semipublic Resource' do
  before :all do
    %w[ @user_model @user ].each do |ivar|
      raise "+#{ivar}+ should be defined in before block" unless instance_variable_get(ivar)
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
      before { @user = @user_model.new }

      it { @user.attribute_dirty?(:age).should be_false }
    end
  end

  it { @user.should respond_to(:dirty_attributes) }

  describe '#dirty_attributes' do
    describe 'on a saved/clean record' do
      it { @user.dirty_attributes.should be_empty }
    end

    describe 'on a saved/dirty record' do
      before { @user.age = 100 }

      it { @user.dirty_attributes.should == { @user_model.properties[:age] => 100 } }
    end

    describe 'on an saved/set/unset record' do
      before do
        @user.age = 100
        @user.age = 25
      end

      it { @user.dirty_attributes.should be_empty }
    end

    describe 'on an saved/unchanged record' do
      before do
        @user.age = 25
      end

      it { @user.dirty_attributes.should be_empty }
    end

    describe 'on a new/clean record' do
      before { @user = @user_model.new }

      it { @user.dirty_attributes.should be_empty }
    end

    describe 'on a new/dirty record' do
      before { @user = @user_model.new(:age => 100) }

      it { @user.original_attributes.should == { @user_model.properties[:age] => nil } }
    end

    describe 'on an new/set/unset record' do
      before do
        @user = @user_model.new(:age => 100)
        @user.age = nil
      end

      it { @user.dirty_attributes.should == { @user_model.properties[:age] => nil } }
    end

    describe 'on an new/unchanged record' do
      before do
        @user = @user_model.new(:age => nil)
      end

      it { @user.dirty_attributes.should == { @user_model.properties[:age] => nil } }
    end
  end

  it { @user.should respond_to(:original_attributes) }

  describe '#original_attributes' do
    describe 'on a saved/clean record' do
      it { @user.original_attributes.should be_empty }
    end

    describe 'on a saved/dirty record' do
      before { @user.age = 100 }

      it { @user.original_attributes.should == { @user_model.properties[:age] => 25 } }
    end

    describe 'on an saved/set/unset record' do
      before do
        @user.age = 100
        @user.age = 25
      end

      it { @user.original_attributes.should be_empty }
    end

    describe 'on an saved/unchanged record' do
      before do
        @user.age = 25
      end

      it { @user.original_attributes.should be_empty }
    end

    describe 'on a new/clean record' do
      before { @user = @user_model.new }

      it { @user.original_attributes.should be_empty }
    end

    describe 'on a new/dirty record' do
      before { @user = @user_model.new(:age => 100) }

      it { @user.original_attributes.should == { @user_model.properties[:age] => nil } }
    end

    describe 'on an new/set/unset record' do
      before do
        @user = @user_model.new(:age => 100)
        @user.age = nil
      end

      it { @user.original_attributes.should == { @user_model.properties[:age] => nil } }
    end

    describe 'on an new/unchanged record' do
      before do
        @user = @user_model.new(:age => nil)
      end

      it { @user.original_attributes.should == { @user_model.properties[:age] => nil } }
    end
  end

  it { @user.should respond_to(:repository) }

  describe '#repository' do
    before :all do
      class ::Statistic
        include DataMapper::Resource

        def self.default_repository_name
          :alternate
        end

        property :id,    Serial
        property :name,  String
        property :value, Integer
      end
    end

    with_alternate_adapter do
      it 'should return the default adapter when nothing is specified' do
        @user_model.create(:name => 'carl').repository.should == @repository
        @user_model.new.repository.should                     == @repository
        @user_model.get('carl').repository.should             == @repository
      end

      it 'should return the default repository for the model' do
        statistic = Statistic.create(:name => 'visits', :value => 2)
        statistic.repository.should        == @alternate_repository
        Statistic.new.repository.should    == @alternate_repository
        Statistic.get(statistic.id).repository.should == @alternate_repository
      end

      it 'should return the repository defined by the current context' do
        @alternate_repository.scope do
          @user_model.new.repository.should                     == @alternate_repository
          @user_model.create(:name => 'carl').repository.should == @alternate_repository
          @user_model.get('carl').repository.should             == @alternate_repository
        end

        @alternate_repository.scope { @user_model.get('carl') }.repository.should == @alternate_repository
      end
    end

  end
end
