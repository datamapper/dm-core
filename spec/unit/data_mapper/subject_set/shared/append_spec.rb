require 'unit/data_mapper/ordered_set/shared/append_spec'

shared_examples_for 'DataMapper::SubjectSet#<< when appending a not yet included entry' do
  it_should_behave_like 'DataMapper::OrderedSet#<< when appending a not yet included entry'
end

shared_examples_for 'DataMapper::SubjectSet#<< when updating an entry with the same cache key and the new entry is already included' do
  it_should_behave_like 'DataMapper::OrderedSet#<< when updating an already included entry'
end

shared_examples_for 'DataMapper::SubjectSet#<< when updating an entry with the same cache key and the new entry is not yet included' do
  its(:entries) { should_not include(entry1) }
  its(:entries) { should     include(entry2) }

  it 'should insert the new entry at the old position' do
    subject.entries.index(entry2).should == @old_index
  end
end
