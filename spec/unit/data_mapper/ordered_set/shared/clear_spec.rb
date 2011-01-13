require 'spec_helper'

shared_examples_for 'DataMapper::OrderedSet#clear when no entries are present' do
  it { should be_empty }
end

shared_examples_for 'DataMapper::OrderedSet#clear when entries are present' do
  it { should be_empty }
end
