require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'spec_helper'))

if ADAPTER
  module ManyToOneSpec
    class Parent
      include DataMapper::Resource

      def self.default_repository_name
        ADAPTER
      end

      property :id,   Serial
      property :name, String
    end

    class Child
      include DataMapper::Resource

      def self.default_repository_name
        ADAPTER
      end

      property :id,   Serial
      property :name, String

      belongs_to :parent, :class_name => 'ManyToOneSpec::Parent'
    end
  end

  describe DataMapper::Associations::ManyToOne::Proxy do
    before do
      ManyToOneSpec::Parent.auto_migrate!
      ManyToOneSpec::Child.auto_migrate!

      @parent      = ManyToOneSpec::Parent.create(:name => 'parent')
      @child       = ManyToOneSpec::Child.create(:name => 'child', :parent => @parent)
      @other       = ManyToOneSpec::Parent.create(:name => 'other parent')
      @association = @child.parent
    end

    describe '#replace' do
      it 'should remove the resource from the collection' do
        @association.should == @parent
        @association.replace(@other)
        @association.should == @other
      end

      it 'should not automatically save that the resource was removed from the association' do
        @association.replace(@other)
        @child.reload.parent.should == @parent
      end

      it 'should return the association' do
        @association.replace(@other).object_id.should == @association.object_id
      end
    end

    describe '#save' do
      describe 'when the parent is nil' do
        before do
          @association.replace(nil)
        end

        it 'should not save the parent' do
          @association.save
        end

        it 'should return false' do
          @association.save.should == false
        end
      end

      describe 'when the parent is not a new record' do
        before do
          @parent.should_not be_new_record
        end

        it 'should not save the parent' do
          @parent.should_not_receive(:save)
          @association.save
        end

        it 'should return true' do
          @association.save.should == true
        end
      end

      describe 'when the parent is a new record' do
        before do
          @parent = ManyToOneSpec::Parent.new(:name => 'unsaved parent')
          @parent.should be_new_record
          @association.replace(@parent)
        end

        it 'should save the parent' do
          @association.save
          @parent.should_not be_new_record
        end

        it 'should return the result of the save' do
          @association.save.should == true
        end
      end
    end

    describe '#reload' do
      before do
        @child.parent_id.should == @parent.id
        @association.replace(@other)
      end

      it 'should not change the foreign key in the child' do
        @child.parent_id.should == @other.id
        @association.reload
        @child.parent_id.should == @other.id
      end

      it 'should return self' do
        @association.reload.object_id.should == @association.object_id
      end
    end
  end
end
