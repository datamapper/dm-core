require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'spec_helper'))

describe DataMapper::Property, 'ParanoidDateTime type' do
  before :all do
    module ::Blog
      class Article
        include DataMapper::Resource

        attr_reader :hook_called

        property :id,         Serial
        property :deleted_at, ParanoidDateTime

        before :destroy do
          @hook_called ||= 0
          @hook_called += 1
        end
      end
    end

    @model = Blog::Article
  end

  supported_by :all do
    describe 'Resource#destroy' do
      subject { @resource.destroy }

      describe 'with a new resource' do
        before do
          @resource = @model.new
        end

        it { should be_false }

        it 'should not delete the resource from the datastore' do
          method(:subject).should_not change { @model.with_deleted.size }.from(0)
        end

        it 'should not set the paranoid column' do
          method(:subject).should_not change { @resource.deleted_at }.from(nil)
        end

        it 'should run the destroy hook' do
          method(:subject).should change { @resource.hook_called }.from(nil).to(1)
        end
      end

      describe 'with a saved resource' do
        before do
          @resource = @model.create
        end

        it { should be_true }

        it 'should not delete the resource from the datastore' do
          method(:subject).should_not change { @model.with_deleted.size }.from(1)
        end

        it 'should set the paranoid column' do
          method(:subject).should change { @resource.deleted_at }.from(nil)
        end

        it 'should run the destroy hook' do
          method(:subject).should change { @resource.hook_called }.from(nil).to(1)
        end
      end
    end

    describe 'Resource#destroy!' do
      subject { @resource.destroy! }

      describe 'with a new resource' do
        before do
          @resource = @model.new
        end

        it { should be_false }

        it 'should not delete the resource from the datastore' do
          method(:subject).should_not change { @model.with_deleted.size }.from(0)
        end

        it 'should not set the paranoid column' do
          method(:subject).should_not change { @resource.deleted_at }.from(nil)
        end

        it 'should not run the destroy hook when #destroy called' do
          method(:subject).should_not change { @resource.hook_called }.from(nil)
        end
      end

      describe 'with a saved resource' do
        before do
          @resource = @model.create
        end

        it { should be_true }

        it 'should delete the resource from the datastore' do
          method(:subject).should change { @model.with_deleted.size }.from(1).to(0)
        end

        it 'should not set the paranoid column' do
          method(:subject).should_not change { @resource.deleted_at }.from(nil)
        end

        it 'should not run the destroy hook when #destroy called' do
          method(:subject).should_not change { @resource.hook_called }.from(nil)
        end
      end
    end

    describe 'Model#with_deleted' do
      before do
        @resource = @model.create
        @resource.destroy
      end

      describe 'with a block' do
        subject { @model.with_deleted { @model.all } }

        it 'should scope the block to return all resources' do
          subject.map { |resource| resource.key }.should == [ @resource.key ]
        end
      end

      describe 'without a block' do
        subject { @model.with_deleted }

        it 'should return a collection scoped to return all resources' do
          subject.map { |resource| resource.key }.should == [ @resource.key ]
        end
      end
    end
  end
end
