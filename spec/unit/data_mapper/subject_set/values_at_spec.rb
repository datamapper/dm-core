require 'spec_helper'
require 'dm-core/support/subject_set'
require 'unit/data_mapper/subject_set/shared/values_at_spec'

describe 'DataMapper::SubjectSet#values_at' do
  before :all do

    class ::Person
      attr_reader :name
      def initialize(name)
        @name = name
      end
    end

  end

  subject { set.values_at(*given_names) }

  let(:set)    { DataMapper::SubjectSet.new(entries) }
  let(:entry1) { Person.new('Alice')                 }
  let(:entry2) { Person.new('Bob'  )                 }

  context 'when one name is given and no entry with the given name is present' do
    let(:given_names) { [ 'Alice' ] }
    let(:entries)     { []          }

    it_should_behave_like 'DataMapper::SubjectSet#values_at when one name is given and no entry with the given name is present'
  end

  context 'when one name is given and an entry with the given name is present' do
    let(:given_names) { [ 'Alice' ] }
    let(:entries)     { [ entry1 ]  }

    it_should_behave_like 'DataMapper::SubjectSet#values_at when one name is given and an entry with the given name is present'
  end

  context 'when more than one name is given and no entry with any of the given names is present' do
    let(:given_names) { [ 'Alice', 'Bob' ] }
    let(:entries)     { []                 }

    it_should_behave_like 'DataMapper::SubjectSet#values_at when more than one name is given and no entry with any of the given names is present'
  end

  context 'when more than one name is given and one entry with one of the given names is present' do
    let(:given_names) { [ 'Alice', 'Bob' ] }
    let(:entries)     { [ entry1 ]         }

    it_should_behave_like 'DataMapper::SubjectSet#values_at when more than one name is given and one entry with one of the given names is present'
  end

  context 'when more than one name is given and an entry for every given name is present' do
    let(:given_names) { [ 'Alice', 'Bob' ] }
    let(:entries)     { [ entry1, entry2 ] }

    it_should_behave_like 'DataMapper::SubjectSet#values_at when more than one name is given and an entry for every given name is present'
  end
end
