require 'spec_helper'
require 'dm-core/support/ordered_set'
require 'unit/data_mapper/ordered_set/shared/each_spec'

describe 'DataMapper::OrderedSet' do
  subject { DataMapper::OrderedSet.new }

  it_should_behave_like 'DataMapper::OrderedSet'
end

describe 'DataMapper::OrderedSet#each' do
  subject { set.each { |entry| yields << entry } }

  let(:set)    { DataMapper::OrderedSet.new([ entry ]) }
  let(:entry)  { 1                                     }
  let(:yields) { []                                    }

  it_should_behave_like 'DataMapper::OrderedSet#each'
end
