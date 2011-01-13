require 'spec_helper'
require 'dm-core/support/ordered_set'
require 'unit/data_mapper/ordered_set/shared/include_spec'

describe 'DataMapper::OrderedSet#include?' do
  subject { ordered_set.include?(entry) }

  let(:ordered_set) { set }

  context 'when the entry is present' do
    let(:set)   { DataMapper::OrderedSet.new([ entry ]) }
    let(:entry) { 1                                     }

    it_should_behave_like 'DataMapper::OrderedSet#include? when the entry is present'
  end

  context 'when the entry is not present' do
    let(:set)   { DataMapper::OrderedSet.new }
    let(:entry) { 1                          }

    it_should_behave_like 'DataMapper::OrderedSet#include? when the entry is not present'
  end
end
