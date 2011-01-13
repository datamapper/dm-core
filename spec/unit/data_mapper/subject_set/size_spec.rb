require 'spec_helper'
require 'dm-core/support/subject_set'
require 'unit/data_mapper/subject_set/shared/size_spec'

describe 'DataMapper::SubjectSet#size' do
  before :all do

    class ::Person
      attr_reader :name
      def initialize(name)
        @name = name
      end
    end

  end

  subject { set.size }

  let(:entry1) { Person.new('Alice') }
  let(:entry2) { Person.new('Bob'  ) }

  context 'when no entry is present' do
    let(:set) { DataMapper::SubjectSet.new }

    it_should_behave_like 'DataMapper::SubjectSet#size when no entry is present'
  end

  context 'when 1 entry is present' do
    let(:set)     { DataMapper::SubjectSet.new(entries) }
    let(:entries) { [ entry1 ]                          }

    it_should_behave_like 'DataMapper::SubjectSet#size when 1 entry is present'
  end

  context 'when more than 1 entry is present' do
    let(:set)           { DataMapper::SubjectSet.new(entries) }
    let(:entries)       { [ entry1, entry2 ]                  }
    let(:expected_size) { entries.size                        }

    it_should_behave_like 'DataMapper::SubjectSet#size when more than 1 entry is present'
  end
end
