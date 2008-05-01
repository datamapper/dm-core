require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'spec_helper'))

describe LazyArray do
  before do
    @nancy  = 'nancy'
    @bessie = 'bessie'
    @steve  = 'steve'

    @lazy_array = LazyArray.new
    @lazy_array.load_with { |la| la.push(@nancy, @bessie) }

    @other = LazyArray.new
    @other.load_with { |la| la.push(@steve) }
  end

  it 'should provide #at' do
    @lazy_array.should respond_to(:at)
  end

  describe '#at' do
    it 'should lookup the element by index' do
      @lazy_array.at(0).should == @nancy
    end
  end

  it 'should provide #clear' do
    @lazy_array.should respond_to(:clear)
  end

  describe '#clear' do
    it 'should return self' do
      @lazy_array.clear.object_id.should == @lazy_array.object_id
    end

    it 'should make the lazy array become empty' do
      @lazy_array.clear.should be_empty
    end
  end

  it 'should provide #collect!' do
    @lazy_array.should respond_to(:collect!)
  end

  describe '#collect!' do
    it 'should return self' do
      @lazy_array.collect! { |element| element }.object_id.should == @lazy_array.object_id
    end

    it 'should iterate over the lazy array' do
      lazy_array = []
      @lazy_array.collect! { |element| lazy_array << element; element }
      lazy_array.should == @lazy_array.entries
    end

    it 'should update the lazy array with the result of the block' do
      @lazy_array.collect! { |element| @steve }.entries.should == [ @steve, @steve ]
    end
  end

  it 'should provide #concat' do
    @lazy_array.should respond_to(:concat)
  end

  describe '#concat' do
    it 'should return self' do
      @lazy_array.concat(@other).object_id.should == @lazy_array.object_id
    end

    it 'should concatenate another lazy array with #concat' do
      concatenated = @lazy_array.concat(@other)
      concatenated.length.should == 3
      concatenated[0].should == @nancy
      concatenated[1].should == @bessie
      concatenated[2].should == @steve
    end
  end

  it 'should provide #delete' do
    @lazy_array.should respond_to(:delete)
  end

  describe '#delete' do
    it 'should delete the matching element from the lazy array' do
      @lazy_array.delete(@nancy).should == @nancy
      @lazy_array.size.should == 1
      @lazy_array.first.should == @bessie
    end

    it 'should use the passed-in block when no element was removed' do
      @lazy_array.size.should == 2
      @lazy_array.delete(@steve) { @steve }.should == @steve
      @lazy_array.size.should == 2
    end
  end

  it 'should provide #delete_at' do
    @lazy_array.should respond_to(:delete_at)
  end

  describe '#delete_at' do
    it 'should delete the element from the lazy array with the index' do
      @lazy_array.delete_at(0).should == @nancy
      @lazy_array.size.should == 1
      @lazy_array.first.should == @bessie
    end
  end

  it 'should provide #each' do
    @lazy_array.should respond_to(:each)
  end

  describe '#each' do
    it 'should return self' do
      @lazy_array.each { |element| }.object_id.should == @lazy_array.object_id
    end

    it 'should iterate over the lazy array' do
      lazy_array = []
      @lazy_array.each { |element| lazy_array << element }
      lazy_array.should == @lazy_array.entries
    end
  end

  it 'should provide #each_index' do
    @lazy_array.should respond_to(:each_index)
  end

  describe '#each_index' do
    it 'should return self' do
      @lazy_array.each_index { |element| }.object_id.should == @lazy_array.object_id
    end

    it 'should iterate over the lazy array by index' do
      indexes = []
      @lazy_array.each_index { |index| indexes << index }
      indexes.should == [ 0, 1 ]
    end
  end

  it 'should provide #empty?' do
    @lazy_array.should respond_to(:empty?)
  end

  describe '#empty?' do
    it 'should return true if the lazy array has entries' do
      @lazy_array.length.should == 2
      @lazy_array.empty?.should be_false
    end

    it 'should return false if the lazy array has no entries' do
      @lazy_array.clear
      @lazy_array.length.should == 0
      @lazy_array.empty?.should be_true
    end
  end

  it 'should provide #entries' do
    @lazy_array.should respond_to(:entries)
  end

  describe '#entries' do
    it 'should return an Array' do
      @lazy_array.entries.should be_kind_of(Array)
    end
  end

  it 'should provide #eql?' do
    @lazy_array.should respond_to(:eql?)
  end

  describe '#eql?' do
    it 'should return true if for the same lazy array' do
      @lazy_array.object_id.should == @lazy_array.object_id
      @lazy_array.entries.should == @lazy_array.entries
      @lazy_array.should be_eql(@lazy_array)
    end

    it 'should return true for duplicate lazy arrays' do
      dup = @lazy_array.dup
      dup.should be_kind_of(LazyArray)
      dup.object_id.should_not == @lazy_array.object_id
      dup.should be_eql(@lazy_array)
    end

    it 'should return false for different lazy arrays' do
      @lazy_array.should_not be_eql(@other)
    end
  end

  it 'should provide #fetch' do
    @lazy_array.should respond_to(:fetch)
  end

  describe '#fetch' do
    it 'should lookup the element with an index' do
      @lazy_array.fetch(0).should == @nancy
    end

    it 'should throw an IndexError exception if the index is outside the array' do
      lambda { @lazy_array.fetch(99) }.should raise_error(IndexError)
    end

    it 'should subsitute the default if the index is outside the array' do
      element = 'cow'
      @lazy_array.fetch(99, element).object_id.should == element.object_id
    end

    it 'should substitude the value returned by the default block if the index is outside the array' do
      element = 'cow'
      @lazy_array.fetch(99) { element }.object_id.should == element.object_id
    end
  end

  it 'should provide #first' do
    @lazy_array.should respond_to(:first)
  end

  describe '#first' do
    describe 'with no arguments' do
      it 'should return the first element in the lazy array' do
        @lazy_array.first.should == @nancy
      end
    end

    describe 'with number of results specified' do
      it 'should return a LazyArray ' do
        lazy_array = @lazy_array.first(2)
        lazy_array.should be_kind_of(LazyArray)
        lazy_array.object_id.should_not == @lazy_array.object_id
        lazy_array.length.should == 2
        lazy_array.first.should == @nancy
        lazy_array.last.should == @bessie
      end
    end
  end

  it 'should provide #index' do
    @lazy_array.should respond_to(:index)
  end

  describe '#index' do
    it 'should return an Integer' do
      @lazy_array.index(@nancy).should be_kind_of(Integer)
    end

    it 'should return the index for the first matching element in the lazy array' do
      @lazy_array.index(@nancy).should == 0
    end
  end

  it 'should provide #insert' do
    @lazy_array.should respond_to(:insert)
  end

  describe '#insert' do
    it 'should return self' do
      @lazy_array.insert(1, @steve).object_id.should == @lazy_array.object_id
    end

    it 'should insert the element at index in the lazy array' do
      @lazy_array.insert(1, @steve)
      @lazy_array[0].should == @nancy
      @lazy_array[1].should == @steve
      @lazy_array[2].should == @bessie
    end
  end

  it 'should provide #last' do
    @lazy_array.should respond_to(:last)
  end

  describe '#last' do
    describe 'with no arguments' do
      it 'should return the last element in the lazy array' do
        @lazy_array.last.should == @bessie
      end
    end

    describe 'with number of results specified' do
      it 'should return a LazyArray ' do
        lazy_array = @lazy_array.last(2)
        lazy_array.should be_kind_of(LazyArray)
        lazy_array.object_id.should_not == @lazy_array.object_id
        lazy_array.length.should == 2
        lazy_array.first.should == @nancy
        lazy_array.last.should == @bessie
      end
    end
  end

  it 'should provide #length' do
    @lazy_array.should respond_to(:length)
  end

  describe '#length' do
    it 'should return an Integer' do
      @lazy_array.length.should be_kind_of(Integer)
    end

    it 'should return the length of the lazy array' do
      @lazy_array.length.should == 2
    end
  end

  it 'should provide #loaded?' do
    @lazy_array.should respond_to(:loaded?)
  end

  describe '#loaded?' do
    it 'should return true for an initialized lazy array' do
      @lazy_array.at(0)  # initialize the array
      @lazy_array.should be_loaded
    end

    it 'should return false for an uninitialized lazy array' do
      uninitialized = LazyArray.new
      uninitialized.should_not be_loaded
    end
  end

  it 'should provide #partition' do
    @lazy_array.should respond_to(:partition)
  end

  describe '#partition' do
    describe 'return value' do
      before do
        @array = @lazy_array.partition { |e| e == @nancy }
      end

      it 'should be an Array' do
        @array.should be_kind_of(Array)
      end

      it 'should have two entries' do
        @array.length.should == 2
      end

      describe 'first entry' do
        before do
          @true_results = @array.first
        end

        it 'should be a LazyArray' do
          @true_results.should be_kind_of(LazyArray)
        end

        it 'should have one entry' do
          @true_results.length.should == 1
        end

        it 'should contain the entry the block returned true for' do
          @true_results.first.should == @nancy
        end
      end

      describe 'second entry' do
        before do
          @false_results = @array.last
        end

        it 'should be a LazyArray' do
          @false_results.should be_kind_of(LazyArray)
        end

        it 'should have one entry' do
          @false_results.length.should == 1
        end

        it 'should contain the entry the block returned true for' do
          @false_results.first.should == @bessie
        end
      end
    end
  end

  it 'should provide #pop' do
    @lazy_array.should respond_to(:pop)
  end

  describe '#pop' do
    it 'should remove the last element' do
      @lazy_array.pop.should == @bessie
      @lazy_array.length.should == 1
      @lazy_array.first.should == @nancy
    end
  end

  it 'should provide #push' do
    @lazy_array.should respond_to(:push)
  end

  describe '#push' do
    it 'should return self' do
      @lazy_array.push(@steve).object_id.should == @lazy_array.object_id
    end

    it 'should append a element' do
      @lazy_array.push(@steve)
      @lazy_array.length.should == 3
      @lazy_array[0].should == @nancy
      @lazy_array[1].should == @bessie
      @lazy_array[2].should == @steve
    end
  end

  it 'should provide #reject' do
    @lazy_array.should respond_to(:reject)
  end

  describe '#reject' do
    it 'should return a LazyArray with elements that did not match the block' do
      rejected = @lazy_array.reject { |element| false }
      rejected.should be_kind_of(LazyArray)
      rejected.object_id.should_not == @lazy_array.object_id
      rejected.length.should == 2
      rejected.first.should == @nancy
      rejected.last.should == @bessie
    end

    it 'should return an empty Collection if elements matched the block' do
      rejected = @lazy_array.reject { |element| true }
      rejected.should be_kind_of(LazyArray)
      rejected.object_id.should_not == @lazy_array.object_id
      rejected.length.should == 0
    end
  end

  it 'should provide #reject!' do
    @lazy_array.should respond_to(:reject!)
  end

  describe '#reject!' do
    it 'should return self if elements matched the block' do
      @lazy_array.reject! { |element| true }.object_id.should == @lazy_array.object_id
    end

    it 'should return nil if no elements matched the block' do
      @lazy_array.reject! { |element| false }.should be_nil
    end

    it 'should remove elements that matched the block' do
      @lazy_array.reject! { |element| true }
      @lazy_array.should be_empty
    end

    it 'should not remove elements that did not match the block' do
      @lazy_array.reject! { |element| false }
      @lazy_array.length.should == 2
      @lazy_array.first.should == @nancy
      @lazy_array.last.should == @bessie
    end
  end

  it 'should provide #reverse' do
    @lazy_array.should respond_to(:reverse)
  end

  describe '#reverse' do
    it 'should return a LazyArray with reversed entries' do
      reversed = @lazy_array.reverse
      reversed.should be_kind_of(LazyArray)
      reversed.object_id.should_not == @lazy_array.object_id
      reversed.entries.should == @lazy_array.entries.reverse
    end
  end

  it 'should provide #reverse!' do
    @lazy_array.should respond_to(:reverse!)
  end

  describe '#reverse!' do
    it 'should return self' do
      @lazy_array.reverse!.object_id.should == @lazy_array.object_id
    end

    it 'should reverse the order of elements in the lazy array inline' do
      entries = @lazy_array.entries
      @lazy_array.reverse!
      @lazy_array.entries.should == entries.reverse
    end
  end

  it 'should provide #reverse_each' do
    @lazy_array.should respond_to(:reverse_each)
  end

  describe '#reverse_each' do
    it 'should return self' do
      @lazy_array.reverse_each { |element| }.object_id.should == @lazy_array.object_id
    end

    it 'should iterate through the lazy array in reverse' do
      lazy_array = []
      @lazy_array.reverse_each { |element| lazy_array << element }
      lazy_array.should == @lazy_array.entries.reverse
    end
  end

  it 'should provide #rindex' do
    @lazy_array.should respond_to(:rindex)
  end

  describe '#rindex' do
    it 'should return an Integer' do
      @lazy_array.rindex(@nancy).should be_kind_of(Integer)
    end

    it 'should return the index for the last matching element in the lazy array' do
      @lazy_array.rindex(@nancy).should == 0
    end
  end

  it 'should provide #select' do
    @lazy_array.should respond_to(:select)
  end

  describe '#select' do
    it 'should return a LazyArray with elements that matched the block' do
      selected = @lazy_array.select { |element| true }
      selected.should be_kind_of(LazyArray)
      selected.object_id.should_not == @lazy_array.object_id
      selected.entries.should == @lazy_array.entries
    end

    it 'should return an empty Collection if no elements matched the block' do
      selected = @lazy_array.select { |element| false }
      selected.should be_kind_of(LazyArray)
      selected.object_id.should_not == @lazy_array.object_id
      selected.should be_empty
    end
  end

  it 'should provide #shift' do
    @lazy_array.should respond_to(:shift)
  end

  describe '#shift' do
    it 'should remove the first element' do
      @lazy_array.shift.should == @nancy
      @lazy_array.length.should == 1
      @lazy_array.first.should == @bessie
    end
  end

  it 'should provide #slice' do
    @lazy_array.should respond_to(:slice)
  end

  describe '#slice' do
    describe 'with an index' do
      it 'should not modify the lazy array' do
        @lazy_array.slice(0)
        @lazy_array.size.should == 2
      end
    end

    describe 'with a start and length' do
      it 'should return a LazyArray' do
        sliced = @lazy_array.slice(0, 1)
        sliced.should be_kind_of(LazyArray)
        sliced.object_id.should_not == @lazy_array.object_id
        sliced.length.should == 1
        sliced.first.should == @nancy
      end

      it 'should not modify the lazy array' do
        @lazy_array.slice(0, 1)
        @lazy_array.size.should == 2
      end
    end

    describe 'with a Range' do
      it 'should return a LazyArray' do
        sliced = @lazy_array.slice(0..1)
        sliced.should be_kind_of(LazyArray)
        sliced.object_id.should_not == @lazy_array.object_id
        sliced.length.should == 2
        sliced.first.should == @nancy
        sliced.last.should == @bessie
      end

      it 'should not modify the lazy array' do
        @lazy_array.slice(0..1)
        @lazy_array.size.should == 2
      end
    end
  end

  it 'should provide #slice!' do
    @lazy_array.should respond_to(:slice!)
  end

  describe '#slice!' do
    describe 'with an index' do
      it 'should modify the lazy array' do
        @lazy_array.slice!(0)
        @lazy_array.size.should == 1
      end
    end

    describe 'with a start and length' do
      it 'should return a LazyArray' do
        sliced = @lazy_array.slice!(0, 1)
        sliced.should be_kind_of(LazyArray)
        sliced.object_id.should_not == @lazy_array.object_id
        sliced.length.should == 1
        sliced.first.should == @nancy
      end

      it 'should modify the lazy array' do
        @lazy_array.slice!(0, 1)
        @lazy_array.size.should == 1
      end
    end

    describe 'with a Range' do
      it 'should return a LazyArray' do
        sliced = @lazy_array.slice(0..1)
        sliced.should be_kind_of(LazyArray)
        sliced.object_id.should_not == @lazy_array.object_id
        sliced.length.should == 2
        sliced.first.should == @nancy
        sliced.last.should == @bessie
      end

      it 'should modify the lazy array' do
        @lazy_array.slice!(0..1)
        @lazy_array.size.should == 0
      end
    end
  end

  it 'should provide #sort' do
    @lazy_array.should respond_to(:sort)
  end

  describe '#sort' do
    it 'should return a LazyArray' do
      sorted = @lazy_array.sort { |a,b| a <=> b }
      sorted.should be_kind_of(LazyArray)
      sorted.object_id.should_not == @lazy_array.object_id
    end

    it 'should sort the elements' do
      sorted = @lazy_array.sort { |a,b| a <=> b }
      sorted.entries.should == @lazy_array.entries.reverse
    end
  end

  it 'should provide #sort!' do
    @lazy_array.should respond_to(:sort!)
  end

  describe '#sort!' do
    it 'should return self' do
      @lazy_array.sort! { |a,b| 0 }.object_id.should == @lazy_array.object_id
    end

    it 'should sort the Collection in place' do
      original_entries =  @lazy_array.entries
      @lazy_array.length.should == 2
      @lazy_array.sort! { |a,b| a <=> b }
      @lazy_array.length.should == 2
      @lazy_array.entries.should == original_entries.reverse
    end
  end

  it 'should provide #to_a' do
    @lazy_array.should respond_to(:to_a)
  end

  describe '#to_a' do
    it 'should return an Array' do
      @lazy_array.to_a.should be_kind_of(Array)
    end
  end

  it 'should provide #to_ary' do
    @lazy_array.should respond_to(:to_ary)
  end

  describe '#to_ary' do
    it 'should return an Array' do
      @lazy_array.to_ary.should be_kind_of(Array)
    end
  end

  it 'should provide #unshift' do
    @lazy_array.should respond_to(:unshift)
  end

  describe '#unshift' do
    it 'should return self' do
      @lazy_array.unshift(@steve).object_id.should == @lazy_array.object_id
    end

    it 'should prepend a element' do
      @lazy_array.unshift(@steve)
      @lazy_array.length.should == 3
      @lazy_array[0].should == @steve
      @lazy_array[1].should == @nancy
      @lazy_array[2].should == @bessie
    end
  end

  it 'should provide #values_at' do
    @lazy_array.should respond_to(:values_at)
  end

  describe '#values_at' do
    it 'should return a LazyArray' do
      values = @lazy_array.values_at(0)
      values.class.should == LazyArray
      values.should be_kind_of(LazyArray)
      values.object_id.should_not == @lazy_array.object_id
    end

    it 'should return a LazyArray of the elements at the index' do
      @lazy_array.values_at(0).entries.should == [ @nancy ]
    end
  end

  describe 'an unknown method' do
    it 'should raise an exception' do
      lambda { @lazy_array.unknown }.should raise_error(NoMethodError)
    end
  end
end
