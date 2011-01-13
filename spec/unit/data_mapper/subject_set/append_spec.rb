require 'spec_helper'
require 'dm-core/support/subject_set'
require 'unit/data_mapper/subject_set/shared/append_spec'

describe 'DataMapper::SubjectSet#<<' do
  before :all do

    class ::Person
      attr_reader :name
      attr_reader :hobby
      def initialize(name, hobby)
        @name  = name
        @hobby = hobby
      end
    end

  end

  before do
    @old_size  = set.size
    @old_index = set.entries.index(entry1)
  end

  subject { set << entry2 }

  let(:set)    { DataMapper::SubjectSet.new([ entry1 ]) }
  let(:entry1) { Person.new('snusnu', 'programming')    }
  let(:entry2) { Person.new('snusnu', 'tabletennis')    }

  context 'when appending a not yet included entry' do
    let(:entry2) { Person.new('Alice', 'cryptography') }

    it_should_behave_like 'DataMapper::SubjectSet#<< when appending a not yet included entry'
  end

  context 'when updating an entry with the same cache key' do
    context 'and the new entry is already included' do
      let(:entry2) { entry1 }

      it_should_behave_like 'DataMapper::SubjectSet#<< when updating an entry with the same cache key and the new entry is already included'
    end

    context 'and the new entry is not yet included' do
      it_should_behave_like 'DataMapper::SubjectSet#<< when updating an entry with the same cache key and the new entry is not yet included'
    end
  end
end
