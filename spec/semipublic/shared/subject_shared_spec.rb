share_examples_for 'A semipublic Subject' do
  describe '#default?' do
    describe 'with a default' do
      subject { @subject_with_default.default? }

      it { should be(true) }
    end

    describe 'without a default' do
      subject { @subject_without_default.default? }

      it { should be(false) }
    end
  end

  describe '#default_for' do
    describe 'without a default' do
      subject { @subject_without_default.default_for(@resource) }

      it 'should match the default value' do
        DataMapper::Ext.blank?(subject).should == true
      end

      it 'should be used as a default for the subject accessor' do
        should == @resource.__send__(@subject_without_default.name)
      end

      it 'should persist the value' do
        @resource.save.should be(true)
        @resource = @resource.model.get!(*@resource.key)
        @resource.without_default.should == subject
      end
    end

    describe 'with a default value' do
      subject { @subject_with_default.default_for(@resource) }

      it 'should match the default value' do
        if @default_value.kind_of?(DataMapper::Resource)
          subject.key.should == @default_value.key
        else
          should == @default_value
        end
      end

      it 'should be used as a default for the subject accessor' do
        should == @resource.__send__(@subject_with_default.name)
      end

      it 'should persist the value' do
        @resource.save.should be(true)
        @resource = @resource.model.get!(*@resource.key)
        @resource.with_default.should == subject
      end
    end

    describe 'with a default value responding to #call' do
      subject { @subject_with_default_callable.default_for(@resource) }

      it 'should match the default value' do
        if @default_value.kind_of?(DataMapper::Resource)
          subject.key.should == @default_value_callable.key
        else
          should == @default_value_callable
        end
      end

      it 'should be used as a default for the subject accessor' do
        should == @resource.__send__(@subject_with_default_callable.name)
      end

      it 'should persist the value' do
        @resource.save.should be(true)
        @resource = @resource.model.get!(*@resource.key)
        @resource.with_default_callable.should == subject
      end
    end
  end
end
