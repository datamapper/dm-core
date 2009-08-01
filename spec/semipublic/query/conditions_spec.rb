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
    class ::Mass < DataMapper::Type
      primitive Integer

      def self.load(value, property)
        { 1 => 'Small', 2 => 'Large', 3 => 'XLarge' }[value]
      end

      def self.dump(value, property)
        { 'Small' => 1, 'Large' => 2, 'XLarge' => 3 }[value]
      end
    end

    class ::Heffalump
      include DataMapper::Resource

      property :id,        Serial
      property :color,     String
      property :num_spots, Integer
      property :striped,   Boolean
      property :mass,      Mass,    :default => 'Large', :nullable => false

      belongs_to :parent, Heffalump

      # Heffalumps are surprisingly picky when it comes to choosing friends --
      # they greatly prefer the company of similarly sized beasts. :)
      has n, :mass_mates, Heffalump, :child_key => [:mass], :parent_key => [:mass]
    end

    @heff1 = Heffalump.new(:id => 1, :num_spots => 1, :color => 'green', :striped => true,  :mass => 'Small')
    @heff2 = Heffalump.new(:id => 2, :num_spots => 2, :color => 'green', :striped => false, :mass => 'Large',  :parent => @heff1)
    @heff3 = Heffalump.new(:id => 3, :num_spots => 3, :color => 'blue',  :striped => false, :mass => 'XLarge', :parent => @heff2)
  end

  describe 'Operations' do
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

  describe 'Comparisons' do
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

    it 'should initialize as InclusionComparison for the :in comparator' do
      comp = Comparison.new(:in, Heffalump.num_spots, [ 2 ])
      comp.should be_kind_of(InclusionComparison)
    end

    describe 'EqualToComparison' do
      describe 'with a value matching the property primitive' do
        before :all do
          @comp = Comparison.new(:eql, Heffalump.striped, false)
        end

        it_should_behave_like 'A valid query condition'

        it 'should match records that equal the given value' do
          @comp.should match(@heff2)
          @comp.should match(@heff3)
        end

        it 'should not match records that do not equal the given value' do
          @comp.should_not match(@heff1)
        end
      end

      describe 'with a value coerced into the property primitive' do
        before :all do
          @comp = Comparison.new(:eql, Heffalump.striped, 'false')
        end

        it_should_behave_like 'A valid query condition'

        it 'should match records that equal the given value' do
          @comp.should match(@heff2)
          @comp.should match(@heff3)
        end

        it 'should not match records that do not equal the given value' do
          @comp.should_not match(@heff1)
        end
      end

      describe 'with a value from a custom type' do
        before :all do
          @comp = Comparison.new(:eql, Heffalump.mass, 'Large')
        end

        it_should_behave_like 'A valid query condition'

        it 'should match records that equal the given value' do
          @comp.should match(@heff2)
        end

        it 'should not match records that do not equal the given value' do
          @comp.should_not match(@heff1)
          @comp.should_not match(@heff3)
        end
      end

      describe 'with a relationship subject' do
        before :all do
          @comp = Comparison.new(:eql, Heffalump.relationships[:parent], @heff1)
        end

        it_should_behave_like 'A valid query condition'

        it 'should match records that equal the given value' do
          @comp.should match(@heff2)
        end

        it 'should not match records that do not equal the given value' do
          @comp.should_not match(@heff1)
          @comp.should_not match(@heff3)
        end
      end

      describe 'with a relationship subject using a custom type key' do
        before :all do
          @comp = Comparison.new(:eql, Heffalump.relationships[:mass_mates], @heff1)
        end

        it_should_behave_like 'A valid query condition'

        it 'should match records that equal the given value' do
          @comp.should match(Heffalump.new(:id => 4, :mass => 'Small'))
          @comp.should match(@heff1)
        end

        it 'should not match records that do not equal the given value' do
          @comp.should_not match(@heff2)
          @comp.should_not match(@heff3)
        end
      end
    end

    describe 'InclusionComparison' do
      describe 'with a value matching the property primitive' do
        before :all do
          @comp = Comparison.new(:in, Heffalump.num_spots, 1..2)
        end

        it_should_behave_like 'A valid query condition'

        it 'should match records that equal the given value' do
          @comp.should match(@heff1)
          @comp.should match(@heff2)
        end

        it 'should not match records that do not equal the given value' do
          @comp.should_not match(@heff3)
        end
      end

      describe 'with a value coerced into the property primitive' do
        before :all do
          @comp = Comparison.new(:in, Heffalump.num_spots, '1'..'2')
        end

        it_should_behave_like 'A valid query condition'

        it 'should match records that equal the given value' do
          @comp.should match(@heff1)
          @comp.should match(@heff2)
        end

        it 'should not match records that do not equal the given value' do
          @comp.should_not match(@heff3)
        end
      end

      describe 'with a value from a custom type' do
        before :all do
          @comp = Comparison.new(:in, Heffalump.mass, ['Small', 'Large'])
        end

        it_should_behave_like 'A valid query condition'

        it 'should match records that equal the given value' do
          @comp.should match(@heff1)
          @comp.should match(@heff2)
        end

        it 'should not match records that do not equal the given value' do
          @comp.should_not match(@heff3)
        end
      end

      describe 'with a relationship subject' do
        before :all do
          @comp = Comparison.new(:in, Heffalump.relationships[:parent], [@heff1, @heff2])
        end

        it_should_behave_like 'A valid query condition'

        it 'should match records that equal the given value' do
          @comp.should match(@heff2)
          @comp.should match(@heff3)
        end

        it 'should not match records that do not equal the given value' do
          @comp.should_not match(@heff1)
        end
      end

      describe 'with a relationship subject using a custom type key' do
        before :all do
          @comp = Comparison.new(:in, Heffalump.relationships[:mass_mates], [@heff1, @heff2])
        end

        it_should_behave_like 'A valid query condition'

        it 'should match records that equal the given value' do
          @comp.should match(Heffalump.new(:mass => 'Small'))
          @comp.should match(Heffalump.new(:mass => 'Large'))
          @comp.should match(@heff1)
          @comp.should match(@heff2)
        end

        it 'should not match records that do not equal the given value' do
          @comp.should_not match(@heff3)
        end
      end
    end

    describe 'GreaterThanComparison' do
      describe 'with a value matching the property primitive' do
        before :all do
          @comp = Comparison.new(:gt, Heffalump.num_spots, 2)
        end

        it_should_behave_like 'A valid query condition'

        it 'should match records that are greater than the given value' do
          @comp.should match(@heff3)
        end

        it 'should not match records that are not greater than the given value' do
          @comp.should_not match(@heff1)
          @comp.should_not match(@heff2)
        end
      end

      describe 'with a value coerced into the property primitive' do
        before :all do
          @comp = Comparison.new(:gt, Heffalump.num_spots, '2')
        end

        it_should_behave_like 'A valid query condition'

        it 'should match records that are greater than the given value' do
          @comp.should match(@heff3)
        end

        it 'should not match records that are not greater than the given value' do
          @comp.should_not match(@heff1)
          @comp.should_not match(@heff2)
        end
      end
    end

    describe 'GreaterThanOrEqualToComparison' do
      describe 'with a value matching the property primitive' do
        before :all do
          @comp = Comparison.new(:gte, Heffalump.num_spots, 2)
        end

        it_should_behave_like 'A valid query condition'

        it 'should match records that are greater than or equal to the given value' do
          @comp.should match(@heff2)
          @comp.should match(@heff3)
        end

        it 'should not match records that are not greater than or equal to the given value' do
          @comp.should_not match(@heff1)
        end
      end

      describe 'with a value coerced into the property primitive' do
        before :all do
          @comp = Comparison.new(:gte, Heffalump.num_spots, 2.0)
        end

        it_should_behave_like 'A valid query condition'

        it 'should match records that are greater than or equal to the given value' do
          @comp.should match(@heff2)
          @comp.should match(@heff3)
        end

        it 'should not match records that are not greater than or equal to the given value' do
          @comp.should_not match(@heff1)
        end
      end
    end

    describe 'LessThanComparison' do
      describe 'with a value matching the property primitive' do
        before :all do
          @comp = Comparison.new(:lt, Heffalump.num_spots, 2)
        end

        it_should_behave_like 'A valid query condition'

        it 'should match records that are less than the given value' do
          @comp.should match(@heff1)
        end

        it 'should not match records that are not less than the given value' do
          @comp.should_not match(@heff2)
          @comp.should_not match(@heff3)
        end
      end

      describe 'with a value coerced into the property primitive' do
        before :all do
          @comp = Comparison.new(:lt, Heffalump.num_spots, BigDecimal('2.0'))
        end

        it_should_behave_like 'A valid query condition'

        it 'should match records that are less than the given value' do
          @comp.should match(@heff1)
        end

        it 'should not match records that are not less than the given value' do
          @comp.should_not match(@heff2)
          @comp.should_not match(@heff3)
        end
      end
    end

    describe 'LessThanOrEqualToComparison' do
      describe 'with a value matching the property primitive' do
        before :all do
          @comp = Comparison.new(:lte, Heffalump.num_spots, 2)
        end

        it_should_behave_like 'A valid query condition'

        it 'should match records that are less than or equal to the given value' do
          @comp.should match(@heff1)
          @comp.should match(@heff2)
        end

        it 'should not match records that are not less than or equal to the given value' do
          @comp.should_not match(@heff3)
        end
      end

      describe 'with a value coerced into the property primitive' do
        before :all do
          @comp = Comparison.new(:lte, Heffalump.num_spots, '2')
        end

        it_should_behave_like 'A valid query condition'

        it 'should match records that are less than or equal to the given value' do
          @comp.should match(@heff1)
          @comp.should match(@heff2)
        end

        it 'should not match records that are not less than or equal to the given value' do
          @comp.should_not match(@heff3)
        end
      end
    end

    describe 'RegexpComparison' do
      before :all do
        @comp = Comparison.new(:regexp, Heffalump.color, /green/)
        @heff2.color = 'forest green'
      end

      it_should_behave_like 'A valid query condition'

      it 'should match records that match the regexp' do
        @comp.should match(@heff1)
        @comp.should match(@heff2)
      end

      it "should not match records that don't match the regexp" do
        @comp.should_not match(@heff3)
      end

    end

  end

end
