require 'spec_helper'

shared_examples_for 'DataMapper::OrderedSet#delete when deleting an already included entry' do
  its(:entries) { should_not include(entry1) }
  its(:entries) { should     include(entry2) }
  its(:entries) { should     include(entry3) }

  it 'should correct the index' do
    ordered_set.index(entry1).should be_nil
    ordered_set.index(entry2).should == 0
    ordered_set.index(entry3).should == 1
  end
end

shared_examples_for 'DataMapper::OrderedSet#delete when deleting a not yet included entry' do
  its(:entries) { should include(entry1) }
  its(:entries) { should include(entry2) }
  its(:entries) { should include(entry3) }

  it 'should not alter the index' do
    ordered_set.index(entry1).should == 0
    ordered_set.index(entry2).should == 1
    ordered_set.index(entry3).should == 2
  end
end
