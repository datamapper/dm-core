require 'spec_helper'
require 'dm-core/support/ordered_set'

describe 'DataMapper::OrderedSet#hash' do
  subject { ordered_set.hash }

  let(:entry)       { 1                                     }
  let(:ordered_set) { DataMapper::OrderedSet.new([ entry ]) }

  it { should be_kind_of(Integer) }
  it { should == ordered_set.class.hash ^ ordered_set.entries.hash }
end
