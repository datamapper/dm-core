require 'spec_helper'

shared_examples_for 'DataMapper::SubjectSet#[] when the entry with the given name is not present' do
  it { should be_nil }
end

shared_examples_for 'DataMapper::SubjectSet#[] when the entry with the given name is present' do
  it { should == entry }
end
