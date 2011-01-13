require 'unit/data_mapper/ordered_set/shared/clear_spec'

shared_examples_for 'DataMapper::SubjectSet#clear when no entries are present' do
  it_should_behave_like 'DataMapper::OrderedSet#clear when no entries are present'
end

shared_examples_for 'DataMapper::SubjectSet#clear when entries are present' do
  it_should_behave_like 'DataMapper::OrderedSet#clear when entries are present'
end
