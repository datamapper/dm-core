require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'spec_helper'))

include DataMapper::Query::Conditions

module ComparisonSpecHelpers

  def match(record)
    ComparisonMatcher.new(record)
  end

  class ComparisonMatcher

    def initialize(record)
      @record = record
    end

    def matches?(comparison)
      @comparison = comparison
      comparison.matches?(@record)
    end

    def failure_message
      "Expected #{@comparison.inspect} to match #{@record.inspect}"
    end

    def negative_failure_message
      "Expected #{@comparison.inspect} to NOT match #{@record.inspect}"
    end

  end

end

describe DataMapper::Query::Conditions do

  include ComparisonSpecHelpers

  before :all do
    class ::Heffalump
      include DataMapper::Resource

      property :id,        Serial
      property :color,     String
      property :num_spots, Integer
      property :striped,   Boolean
    end

    @heff1 = Heffalump.new(:num_spots => 1, :color => 'green')
    @heff2 = Heffalump.new(:num_spots => 2, :color => 'green')
    @heff3 = Heffalump.new(:num_spots => 3, :color => 'blue')

  end

  describe "Operations" do
    before do
      @comp1 = Comparison.new(:eql, Heffalump.num_spots, 1)
      @comp2 = Comparison.new(:eql, Heffalump.color, 'green')
    end

    it 'should initialize an AbstractOperation object' do
      op = Operation.new(:and)
      op.should be_kind_of(AbstractOperation)
    end

    {
      :and => AndOperation,
      :or  => OrOperation,
      :not => NotOperation
    }.each do |operand, klass|
      it "should initialize as #{klass} for the #{operand} operator" do
        op = Operation.new(operand)
        op.should be_kind_of(klass)
      end
    end

    it 'should set the remaining args in @operands' do
      op = Operation.new(:and, @comp1, @comp2)
      op.operands.should == [@comp1, @comp2]
    end

    it 'should have operands be empty of no operands are provided' do
      op = Operation.new(:and)
      op.operands.should == []
    end

    describe 'NotOperation' do
      before do
        @op = Operation.new(:not, @comp1)
      end

      it 'should not allow more than one operand' do
        lambda {
          Operation.new(:not, @comp1, @comp2)
        }.should raise_error(InvalidOperation)
      end

      it 'should negate the comparison' do
        @comp1.should match(@heff1)
        @op.should_not match(@heff1)
      end
    end

    describe 'AndOperation' do
      before do
        @op = Operation.new(:and, @comp1, @comp2)
      end

      it 'should match if all comparisons match' do
        @comp1.should match(@heff1)
        @comp2.should match(@heff1)

        @op.should match(@heff1)
      end

      it 'should not match of any of the comparisons does not match' do
        @comp1.should_not match(@heff2)

        @op.should_not match(@heff2)
      end
    end

    describe 'OrOperation' do
      before do
        @op = Operation.new(:or, @comp1, @comp2)
      end

      it 'should match if any of the comparisons match' do
        @comp1.should_not match(@heff2)
        @comp2.should match(@heff2)

        @op.should match(@heff2)
      end

      it 'should not match if none of the comparisons match' do
        @comp1.should_not match(@heff3)
        @comp2.should_not match(@heff3)

        @op.should_not match(@heff3)
      end
    end
  end

  describe "Comparisons" do
    it 'should initialize an AbstractComparison object' do
      comp = Comparison.new(:eql, Heffalump.num_spots, 1)
      comp.should be_kind_of(AbstractComparison)
    end

    {
      :eql    => EqualToComparison,
      :gt     => GreaterThanComparison,
      :gte    => GreaterThanOrEqualToComparison,
      :lt     => LessThanComparison,
      :lte    => LessThanOrEqualToComparison,
      :regexp => RegexpComparison
    }.each do |slug, klass|
      it "should initialize as #{klass} for the #{slug} comparator" do
        comp = Comparison.new(slug, Heffalump.num_spots, 2)
        comp.should be_kind_of(klass)
      end
    end

    it "should initialize as InclusionComparison for the :in comparator" do
      comp = Comparison.new(:in, Heffalump.num_spots, [ 2 ])
      comp.should be_kind_of(InclusionComparison)
    end

    describe "EqualToComparison" do
      before do
        @comp = Comparison.new(:eql, Heffalump.num_spots, 1)
      end

      it "should match records that equal the given value" do
        @comp.should match(@heff1)
      end

      it "should not match records that do not equal the given value" do
        @comp.should_not match(@heff2)
      end
    end

    describe "InclusionComparison" do
      before do
        @comp = Comparison.new(:in, Heffalump.num_spots, 1..2)
      end

      it "should match records that equal the given value" do
        @comp.should match(@heff1)
        @comp.should match(@heff2)
      end

      it "should not match records that do not equal the given value" do
        @comp.should_not match(@heff3)
      end
    end

    describe "GreaterThanComparison" do
      before do
        @comp = Comparison.new(:gt, Heffalump.num_spots, 2)
      end

      it "should match records that are greater than the given value" do
        @comp.should match(@heff3)
      end

      it "should not match records that are not greater than the given value" do
        @comp.should_not match(@heff1)
        @comp.should_not match(@heff2)
      end
    end

    describe "GreaterThanOrEqualToComparison" do
      before do
        @comp = Comparison.new(:gte, Heffalump.num_spots, 2)
      end

      it "should match records that are greater than or equal to the given value" do
        @comp.should match(@heff2)
        @comp.should match(@heff3)
      end

      it "should not match records that are not greater than or equal to the given value" do
        @comp.should_not match(@heff1)
      end
    end

    describe "LessThanComparison" do
      before do
        @comp = Comparison.new(:lt, Heffalump.num_spots, 2)
      end

      it "should match records that are less than the given value" do
        @comp.should match(@heff1)
      end

      it "should not match records that are not less than the given value" do
        @comp.should_not match(@heff2)
        @comp.should_not match(@heff3)
      end
    end

    describe "LessThanOrEqualToComparison" do
      before do
        @comp = Comparison.new(:lte, Heffalump.num_spots, 2)
      end

      it "should match records that are less than or equal to the given value" do
        @comp.should match(@heff1)
        @comp.should match(@heff2)
      end

      it "should not match records that are not less than or equal to the given value" do
        @comp.should_not match(@heff3)
      end
    end

    describe "RegexpComparison" do
      before do
        @comp = Comparison.new(:regexp, Heffalump.color, /green/)
        @heff2.color = 'forest green'
      end

      it "should match records that match the regexp" do
        @comp.should match(@heff1)
        @comp.should match(@heff2)
      end

      it "should not match records that don't match the regexp" do
        @comp.should_not match(@heff3)
      end

    end

  end

end
