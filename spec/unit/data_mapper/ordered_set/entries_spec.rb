require 'spec_helper'
require 'dm-core/support/ordered_set'
require 'unit/data_mapper/ordered_set/shared/entries_spec'

describe 'DataMapper::OrderedSet#entries' do
  subject { ordered_set.entries }

  let(:ordered_set) { set }

  context 'with no entries' do
    let(:set) { DataMapper::OrderedSet.new }

    it_should_behave_like 'DataMapper::OrderedSet#entries with no entries'
  end

  context 'with entries' do
    let(:set)   { DataMapper::OrderedSet.new([ entry ]) }
    let(:entry) { 1                                     }

    it_should_behave_like 'DataMapper::OrderedSet#entries with entries'
  end
end
