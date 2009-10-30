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
