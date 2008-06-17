require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'spec_helper'))

describe DataMapper::Associations::ManyToOne do
  it 'should allow a declaration' do
    lambda do
      class Vehicle
        belongs_to :manufacturer
      end
    end.should_not raise_error
  end
end

describe DataMapper::Associations::ManyToOne::Proxy do
  before do
    @child        = mock('child', :kind_of? => true)
    @parent       = mock('parent')
    @relationship = mock('relationship', :kind_of? => true, :repository_name => :default, :get_parent => @parent, :attach_parent => nil)
    @association  = DataMapper::Associations::ManyToOne::Proxy.new(@relationship, @child)

    @association.replace(@parent)
  end

  it 'should provide #replace' do
    @association.should respond_to(:replace)
  end

  describe '#replace' do
    before do
      @resource = mock('resource')
    end

    before do
      @relationship.should_receive(:attach_parent).with(@child, @resource)
    end

    it 'should remove the resource from the collection' do
      @association.should == @parent
      @association.replace(@resource)
      @association.should == @resource
    end

    it 'should not automatically save that the resource was removed from the association' do
      @resource.should_not_receive(:save)
      @association.replace(@resource)
    end

    it 'should return the association' do
      @association.replace(@resource).object_id.should == @association.object_id
    end
  end

  it 'should provide #save' do
    @association.should respond_to(:replace)
  end

  describe '#save' do
    describe 'when the parent is nil' do
      before do
        @parent.should_receive(:nil?).with(no_args).and_return(true)
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
        @parent.should_receive(:new_record?).with(no_args).and_return(false)
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
        @parent.should_receive(:new_record?).with(no_args).and_return(true)
      end

      it 'should save the parent' do
        @parent.should_receive(:save).with(no_args)
        @association.save
      end

      it 'should return the result of the save' do
        save_results = mock('save results')
        @parent.should_receive(:save).with(no_args).and_return(save_results)
        @association.save.object_id.should == save_results.object_id
      end
    end
  end

  it 'should provide #reload' do
    @association.should respond_to(:reload)
  end

  describe '#reload' do
    it 'should replace the parent with nil' do
      @association.should_receive(:replace).with(nil)
      @association.reload
    end

    it 'should return self' do
      @association.reload.object_id.should == @association.object_id
    end
  end

end
