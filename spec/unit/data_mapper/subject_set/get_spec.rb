require 'spec_helper'
require 'dm-core/support/subject_set'
require 'unit/data_mapper/subject_set/shared/get_spec'

describe 'DataMapper::SubjectSet#[]' do
  before :all do

    class ::Person
      attr_reader :name
      def initialize(name)
        @name = name
      end
    end

  end

  subject { set[name] }

  let(:set  ) { DataMapper::SubjectSet.new(entries) }
  let(:entry) { Person.new(name)                    }
  let(:name ) { 'Alice'                             }

  context 'when the entry with the given name is not present' do
    let(:entries) { [] }

    it_should_behave_like 'DataMapper::SubjectSet#[] when the entry with the given name is not present'
  end

  context 'when the entry with the given name is present' do
    let(:entries) { [ entry ] }

    it_should_behave_like 'DataMapper::SubjectSet#[] when the entry with the given name is present'
  end
end
