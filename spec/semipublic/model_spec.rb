require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

describe DataMapper::Model do

  it { should respond_to(:append_inclusions) }

  describe '.append_inclusions' do
    module ::Inclusions
      def new_method
      end
    end

    describe 'before the model is defined' do
      before :all do
        DataMapper::Model.append_inclusions(Inclusions)

        class ::User
          include DataMapper::Resource
          property :id, Serial
        end
      end

      it 'should respond to :new_method' do
        User.new.should respond_to(:new_method)
      end

      after :all do
        DataMapper::Model.extra_inclusions.delete(Inclusions)
      end
    end

    describe 'after the model is defined' do
      before :all do
        class ::User
          include DataMapper::Resource
          property :id, Serial
        end
        DataMapper::Model.append_inclusions(Inclusions)
      end

      it 'should respond to :new_method' do
        User.new.should respond_to(:new_method)
      end

      after :all do
        DataMapper::Model.extra_inclusions.delete(Inclusions)
      end
    end
  end

  it { should respond_to(:append_extensions) }

  describe '.append_extensions' do
    module ::Extensions
      def new_method
      end
    end

    describe 'before the model is defined' do
      before :all do
        DataMapper::Model.append_extensions(Extensions)

        class ::User
          include DataMapper::Resource
          property :id, Serial
        end
      end

      it 'should respond to :new_method' do
        User.should respond_to(:new_method)
      end

      after :all do
        DataMapper::Model.extra_extensions.delete(Extensions)
      end
    end

    describe 'after the model is defined' do
      before :all do
        class ::User
          include DataMapper::Resource
          property :id, Serial
        end
        DataMapper::Model.append_extensions(Extensions)
      end

      it 'should respond to :new_method' do
        User.should respond_to(:new_method)
      end

      after :all do
        DataMapper::Model.extra_extensions.delete(Extensions)
      end
    end
  end

  supported_by :all do
    describe ".load" do
      before :all do
        module DataMapper
          class Property
            class StringID < Integer
              key true

              def custom?
                true
              end

              def load(value)
                value.to_s
              end

              def dump(value)
                value.to_i
              end
            end
          end
        end

        class User
          include DataMapper::Resource

          property :foo, StringID
          property :bar, StringID
        end

        DataMapper.finalize
        DataMapper.auto_migrate!
      end

      describe "fetched resource" do
        let(:user_key) { ["1", "2"] }

        before(:all) { User.create(:foo => user_key.first, :bar => user_key.last) }

        subject { User.first }

        it "should correctly load the resource setting clean state" do
          subject.persisted_state.should be_kind_of(DataMapper::Resource::State::Clean)
        end

        it "should use loaded key for IM" do
          subject.repository.identity_map(User).keys.should include(user_key)
        end
      end
    end
  end
end
