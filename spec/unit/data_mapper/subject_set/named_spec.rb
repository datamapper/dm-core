require 'spec_helper'
require 'dm-core/support/subject_set'
require 'unit/data_mapper/subject_set/shared/named_spec'

describe 'DataMapper::SubjectSet#named?' do
  before :all do

    class ::Person
      attr_reader :name
      def initialize(name)
        @name = name
      end
    end

  end

  subject { set.named?(name) }

  let(:entry) { Person.new(name) }
  let(:name ) { 'Alice'          }

  context 'when no entry with the given name is present' do
    let(:set) { DataMapper::SubjectSet.new([]) }

    it_should_behave_like 'DataMapper::SubjectSet#named? when no entry with the given name is present'
  end

  context 'when an entry with the given name is present' do
    let(:set) { DataMapper::SubjectSet.new([ entry ]) }

    it_should_behave_like 'DataMapper::SubjectSet#named? when an entry with the given name is present'
  end
end
