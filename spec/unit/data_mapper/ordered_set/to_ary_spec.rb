require 'spec_helper'
require 'dm-core/support/ordered_set'
require 'unit/data_mapper/ordered_set/shared/to_ary_spec'

describe 'DataMapper::OrderedSet#to_ary' do
  subject { ordered_set.to_ary }

  let(:ordered_set) { DataMapper::OrderedSet.new(entries) }
  let(:entry1) { 1 }
  let(:entry2) { 2 }

  context 'when no entries are present' do
    let(:entries) { [] }

    it_should_behave_like 'DataMapper::OrderedSet#to_ary when no entries are present'
  end

  context 'when entries are present' do
    let(:entries) { [ entry1, entry2 ] }

    it_should_behave_like 'DataMapper::OrderedSet#to_ary when entries are present'
  end
end
