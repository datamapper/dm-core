require 'spec_helper'
require 'dm-core/support/subject_set'
require 'unit/data_mapper/subject_set/shared/entries_spec'

describe 'DataMapper::SubjectSet#entries' do
  before :all do

    class ::Person
      attr_reader :name
      def initialize(name)
        @name = name
      end
    end

  end

  subject { set.entries }

  context 'with no entries' do
    let(:set) { DataMapper::SubjectSet.new }

    it_should_behave_like 'DataMapper::SubjectSet#entries with no entries'
  end

  context 'with entries' do
    let(:set)   { DataMapper::SubjectSet.new([ entry ]) }
    let(:entry) { Person.new('Alice')                   }

    it_should_behave_like 'DataMapper::SubjectSet#entries with entries'
  end
end
