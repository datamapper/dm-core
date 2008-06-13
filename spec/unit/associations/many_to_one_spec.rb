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
    @resource     = mock('resource', :save => true, :new_record? => false)
    @relationship = mock('relationship', :kind_of? => true, :repository_name => :default, :get_parent => @parent)
    @association  = DataMapper::Associations::ManyToOne::Proxy.new(@relationship, @child)
  end

  it 'should provide #replace' do
    @association.should respond_to(:replace)
  end

  describe '#replace' do
    def do_replace
      @association.replace(@resource)
    end

    def return_value
      @association
    end

    it 'should remove the resource from the collection' do
      @association.should == @parent
      do_replace.should == return_value
      @association.should == @resource
    end

    it 'should not automatically save that the resource was removed from the association' do
      @relationship.should_not_receive(:attach_parent)
      do_replace.should == return_value
    end

    it 'should persist the removal after saving the association' do
      do_replace.should == return_value
      @relationship.should_receive(:attach_parent).with(@child, @resource)
      @association.save
    end

    it 'should not automatically save that the children were added to the association' do
      @relationship.should_not_receive(:attach_parent)
      do_replace.should == return_value
    end

    it 'should persist the addition after saving the association' do
      do_replace.should == return_value
      @relationship.should_receive(:attach_parent).with(@child, @resource)
      @association.save
    end
  end
end
