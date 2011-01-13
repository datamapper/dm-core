require 'spec_helper'
require 'dm-core/support/subject_set'
require 'unit/data_mapper/subject_set/shared/to_ary_spec'

describe 'DataMapper::SubjectSet#to_ary' do
  before :all do

    class ::Person
      attr_reader :name
      def initialize(name)
        @name = name
      end
    end

  end

  subject { set.to_ary }

  let(:set)    { DataMapper::SubjectSet.new(entries) }
  let(:entry1) { Person.new('Alice')                 }
  let(:entry2) { Person.new('Bob'  )                 }

  context 'when no entries are present' do
    let(:entries) { [] }

    it_should_behave_like 'DataMapper::SubjectSet#to_ary when no entries are present'
  end

  context 'when entries are present' do
    let(:entries) { [ entry1, entry2 ] }

    it_should_behave_like 'DataMapper::SubjectSet#to_ary when entries are present'
  end
end
