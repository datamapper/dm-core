require 'spec_helper'

shared_examples_for 'DataMapper::OrderedSet#to_ary when no entries are present' do
  it { should be_empty   }
  it { should == entries }
end

shared_examples_for 'DataMapper::OrderedSet#to_ary when entries are present' do
  it { should_not be_empty }
  it { should == entries   }
end
