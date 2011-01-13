require 'spec_helper'

shared_examples_for 'DataMapper::OrderedSet#index when the entry is not present' do
  it { should be(nil) }
end

shared_examples_for 'DataMapper::OrderedSet#index when 1 entry is present' do
  it { should == 0 }
end

shared_examples_for 'DataMapper::OrderedSet#index when 2 entries are present' do
  it { should == 1 }
end
