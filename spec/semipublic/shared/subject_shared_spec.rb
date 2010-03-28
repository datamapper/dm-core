share_examples_for 'A semipublic Subject' do
  describe '#default?' do
    describe 'with a default' do
      subject { @subject_with_default.default? }

      it { should be_true }
    end

    describe 'without a default' do
      subject { @subject_without_default.default? }

      it { should be_false }
    end
  end

  describe '#default_for' do
    describe 'without a default' do
      subject { @subject_without_default.default_for(@resource) }

      it { should == @subject_without_default_value }

      it 'should be used as a default for the subject accessor' do
        should == @resource.__send__(@subject_without_default.name)
      end
    end

    describe 'with a default value' do
      subject { @subject_with_default.default_for(@resource) }

      it { should == @subject_with_default_value }

      it 'should be used as a default for the subject accessor' do
        should == @resource.__send__(@subject_with_default.name)
      end
    end

    describe 'with a default value responding to #call' do
      subject { @subject_with_default_callable.default_for(@resource) }

      it { should == @subject_with_default_callable_value }

      it 'should be used as a default for the subject accessor' do
        should == @resource.__send__(@subject_with_default_callable.name)
      end
    end
  end
end
