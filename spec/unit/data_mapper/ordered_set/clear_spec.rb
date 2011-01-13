require 'spec_helper'
require 'dm-core/support/ordered_set'
require 'unit/data_mapper/ordered_set/shared/clear_spec'

describe 'DataMapper::OrderedSet#clear' do
  subject { ordered_set.clear }

  let(:ordered_set) { DataMapper::OrderedSet.new(entries) }

  let(:entry1) { 1 }
  let(:entry2) { 2 }

  context 'when no entries are present' do
    let(:entries) { [] }

    it_should_behave_like 'DataMapper::OrderedSet#clear when no entries are present'
  end

  context 'when entries are present' do
    let(:entries) { [ entry1, entry2 ] }

    it_should_behave_like 'DataMapper::OrderedSet#clear when entries are present'
  end
end
