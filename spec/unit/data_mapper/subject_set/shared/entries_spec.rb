require 'unit/data_mapper/ordered_set/shared/entries_spec'

shared_examples_for 'DataMapper::SubjectSet#entries with no entries' do
  it_should_behave_like 'DataMapper::OrderedSet#entries with no entries'
end

shared_examples_for 'DataMapper::SubjectSet#entries with entries' do
  it_should_behave_like 'DataMapper::OrderedSet#entries with entries'
end
