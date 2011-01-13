require 'spec_helper'
require 'dm-core/support/ordered_set'
require 'unit/data_mapper/ordered_set/shared/merge_spec'

describe 'DataMapper::OrderedSet#merge' do

  context 'when merging two empty sets' do
    subject { ordered_set.merge([]) }

    let(:ordered_set) { set                        }
    let(:set)         { DataMapper::OrderedSet.new }

    it_should_behave_like 'DataMapper::OrderedSet#merge when merging two empty sets'
  end

  context 'when merging a set with already present entries' do
    subject { ordered_set.merge([ entry ]) }

    let(:ordered_set) { set                                   }
    let(:set)         { DataMapper::OrderedSet.new([ entry ]) }
    let(:entry)       { 1                                     }

    it_should_behave_like 'DataMapper::OrderedSet#merge when merging a set with already present entries'
  end

  context 'when merging a set with not yet present entries' do
    subject { ordered_set.merge([ entry2 ]) }

    let(:ordered_set) { set                                    }
    let(:set)         { DataMapper::OrderedSet.new([ entry1 ]) }
    let(:entry1)      { 1                                      }
    let(:entry2)      { 2                                      }

    it_should_behave_like 'DataMapper::OrderedSet#merge when merging a set with not yet present entries'
  end
end
