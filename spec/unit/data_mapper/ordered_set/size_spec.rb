require 'spec_helper'
require 'dm-core/support/ordered_set'
require 'unit/data_mapper/ordered_set/shared/size_spec'

describe 'DataMapper::OrderedSet#size' do
  subject { ordered_set.size }

  context 'when no entry is present' do
    let(:ordered_set) { DataMapper::OrderedSet.new }

    it_should_behave_like 'DataMapper::OrderedSet#size when no entry is present'
  end

  context 'when 1 entry is present' do
    let(:ordered_set) { DataMapper::OrderedSet.new([ 1 ]) }

    it_should_behave_like 'DataMapper::OrderedSet#size when 1 entry is present'
  end

  context 'when more than 1 entry is present' do
    let(:ordered_set)   { DataMapper::OrderedSet.new(entries) }
    let(:entries)       { [ 1, 2 ]                            }
    let(:expected_size) { entries.size                        }

    it_should_behave_like 'DataMapper::OrderedSet#size when more than 1 entry is present'
  end
end
