require 'spec_helper'
require 'dm-core/support/subject_set'
require 'unit/data_mapper/subject_set/shared/include_spec'

describe 'DataMapper::SubjectSet#include?' do
  before :all do

    class ::Person
      attr_reader :name
      def initialize(name)
        @name = name
      end
    end

  end

  subject { set.include?(entry) }

  let(:entry) { Person.new('Alice') }

  context 'when the entry is present' do
    let(:set) { DataMapper::SubjectSet.new([ entry ]) }

    it_should_behave_like 'DataMapper::SubjectSet#include? when the entry is present'
  end

  context 'when the entry is not present' do
    let(:set) { DataMapper::SubjectSet.new }

    it_should_behave_like 'DataMapper::SubjectSet#include? when the entry is not present'
  end
end
