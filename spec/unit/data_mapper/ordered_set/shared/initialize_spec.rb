require 'spec_helper'

shared_examples_for 'DataMapper::OrderedSet#initialize when no entries are given' do
  it { should be_empty }

  its(:entries) { should be_empty }
  its(:size)    { should == 0     }
end

shared_examples_for 'DataMapper::OrderedSet#initialize when entries are given and they do not contain duplicates' do
  it { should_not be_empty    }
  it { should include(entry1) }
  it { should include(entry2) }

  its(:size) { should ==  2 }

  it 'should retain insertion order' do
    subject.index(entry1).should == 0
    subject.index(entry2).should == 1
  end
end

shared_examples_for 'DataMapper::OrderedSet#initialize when entries are given and they contain duplicates' do
  it { should_not be_empty    }
  it { should include(entry1) }

  its(:size) { should ==  1 }
end
