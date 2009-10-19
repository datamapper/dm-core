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
end
