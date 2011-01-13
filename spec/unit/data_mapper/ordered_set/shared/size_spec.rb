require 'spec_helper'

shared_examples_for 'DataMapper::OrderedSet#size when no entry is present' do
  it { should == 0 }
end

shared_examples_for 'DataMapper::OrderedSet#size when 1 entry is present' do
  it { should == 1 }
end

shared_examples_for 'DataMapper::OrderedSet#size when more than 1 entry is present' do
  it { should == expected_size }
end
