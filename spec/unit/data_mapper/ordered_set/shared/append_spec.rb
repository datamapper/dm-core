require 'spec_helper'

shared_examples_for 'DataMapper::OrderedSet#<< when appending a not yet included entry' do
  its(:size   ) { should == 2            }
  its(:entries) { should include(entry1) }
  its(:entries) { should include(entry2) }

  it 'should not alter the position of the existing entry' do
    subject.entries.index(entry1).should == @old_index
  end

  it 'should append columns at the end of the set' do
    subject.entries.index(entry2).should == @old_index + 1
  end
end

shared_examples_for 'DataMapper::OrderedSet#<< when updating an already included entry' do
  its(:size   ) { should == 1            }
  its(:entries) { should include(entry2) }

  it 'should not alter the position of the existing entry' do
    subject.entries.index(entry2).should == @old_index
  end
end
