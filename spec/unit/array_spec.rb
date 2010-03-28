require 'dm-core/core_ext/array'

begin
  require 'active_support/hash_with_indifferent_access'
  unless defined?(Mash)
    Mash = ActiveSupport::HashWithIndifferentAccess
  end
rescue LoadError
  require 'extlib/mash'
end

describe Array do
  before :all do
    @array = [ [ :a, [ 1 ] ], [ :b, [ 2 ] ], [ :c, [ 3 ] ] ].freeze
  end

  it { @array.should respond_to(:to_hash) }

  describe '#to_hash' do
    before :all do
      @return = @array.to_hash
    end

    it 'should return a Hash' do
      @return.should be_kind_of(Hash)
    end

    it 'should return expected value' do
      @return.should == { :a => [ 1 ], :b => [ 2 ], :c => [ 3 ] }
    end
  end

  it { @array.should respond_to(:to_mash) }

  describe '#to_mash' do
    before :all do
      @return = @array.to_mash
    end

    it 'should return a Mash' do
      @return.should be_kind_of(Mash)
    end

    it 'should return expected value' do
      @return.should == { 'a' => [ 1 ], 'b' => [ 2 ], 'c' => [ 3 ] }
    end
  end
end
