require 'spec_helper'
require 'dm-core/support/ordered_set'
require 'unit/data_mapper/ordered_set/shared/empty_spec'

describe 'DataMapper::OrderedSet#empty?' do
  subject { set.empty? }

  context 'with no entries in it' do
    let(:set) { DataMapper::OrderedSet.new }

    it_should_behave_like 'DataMapper::OrderedSet#empty? with no entries in it'
  end

  context 'with entries in it' do
    let(:set)   { DataMapper::OrderedSet.new([ entry ]) }
    let(:entry) { 1                                     }

    it_should_behave_like 'DataMapper::OrderedSet#empty? with entries in it'
  end
end
