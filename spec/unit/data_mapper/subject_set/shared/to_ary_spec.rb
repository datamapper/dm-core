require 'unit/data_mapper/ordered_set/shared/to_ary_spec'

shared_examples_for 'DataMapper::SubjectSet#to_ary when no entries are present' do
  it_should_behave_like 'DataMapper::OrderedSet#to_ary when no entries are present'
end

shared_examples_for 'DataMapper::SubjectSet#to_ary when entries are present' do
  it_should_behave_like 'DataMapper::OrderedSet#to_ary when entries are present'
end
