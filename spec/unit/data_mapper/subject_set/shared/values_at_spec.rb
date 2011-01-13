require 'spec_helper'

shared_examples_for 'DataMapper::SubjectSet#values_at when one name is given and no entry with the given name is present' do
  its(:size) { should == given_names.size }

  it 'should contain nil values for the names not found' do
    subject.compact.should be_empty
  end
end

shared_examples_for 'DataMapper::SubjectSet#values_at when one name is given and an entry with the given name is present' do
  its(:size) { should == given_names.size }

  it { should include(entry1) }
end

shared_examples_for 'DataMapper::SubjectSet#values_at when more than one name is given and no entry with any of the given names is present' do
  its(:size) { should == given_names.size }

  it 'should contain nil values for the names not found' do
    subject.compact.should be_empty
  end
end

shared_examples_for 'DataMapper::SubjectSet#values_at when more than one name is given and one entry with one of the given names is present' do
  it { should include(entry1) }

  its(:size) { should == given_names.size }

  it 'should contain nil values for the names not found' do
    subject.compact.size.should == 1
  end
end

shared_examples_for 'DataMapper::SubjectSet#values_at when more than one name is given and an entry for every given name is present' do
  it { should include(entry1) }
  it { should include(entry2) }

  its(:size) { should == given_names.size }

  it 'should not contain any nil values' do
    subject.compact.size.should == given_names.size
  end
end
