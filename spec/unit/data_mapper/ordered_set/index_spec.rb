require 'spec_helper'
require 'dm-core/support/ordered_set'
require 'unit/data_mapper/ordered_set/shared/index_spec'

describe 'DataMapper::OrderedSet#index' do
  subject { ordered_set.index(entry) }

  context 'when the entry is not present' do
    let(:ordered_set) { DataMapper::OrderedSet.new }
    let(:entry)       { 1                          }

    it_should_behave_like 'DataMapper::OrderedSet#index when the entry is not present'
  end

  context 'when 1 entry is present' do
    let(:ordered_set) { DataMapper::OrderedSet.new([ entry ]) }
    let(:entry)       { 1                                     }

    it_should_behave_like 'DataMapper::OrderedSet#index when 1 entry is present'
  end

  context 'when 2 entries are present' do
    let(:ordered_set) { DataMapper::OrderedSet.new([ 2, entry ]) }
    let(:entry)       { 1                                        }

    it_should_behave_like 'DataMapper::OrderedSet#index when 2 entries are present'
  end
end
