require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', 'spec_helper'))

shared_examples_for 'DataMapper::Query::Conditions::AbstractOperation' do
  before :all do
    module ::Blog
      class Article
        include DataMapper::Resource

        property :id,    Serial
        property :title, String, :nullable => false
      end
    end

    @model = Blog::Article
  end

  before do
    class ::OtherOperation < DataMapper::Query::Conditions::AbstractOperation
      slug :other
    end
  end

  before do
    @comparison     = DataMapper::Query::Conditions::Comparison.new(:eql, @model.properties[:title], 'A title')
    @and_operation  = DataMapper::Query::Conditions::Operation.new(:and)
    @or_operation   = DataMapper::Query::Conditions::Operation.new(:or)
    @not_operation  = DataMapper::Query::Conditions::Operation.new(:not)
    @null_operation = DataMapper::Query::Conditions::Operation.new(:null)
    @other          = OtherOperation.new
  end

  it { @operation.class.should respond_to(:new) }

  describe '.new' do
    describe 'with no arguments' do
      subject { @operation.class.new }

      it { should be_kind_of(@operation.class) }
    end

    describe 'with arguments' do
      subject { @operation.class.new(@comparison) }

      it { should be_kind_of(@operation.class) }
    end
  end

  it { @operation.class.should respond_to(:slug) }

  describe '.slug' do
    describe 'with no arguments' do
      subject { @operation.class.slug }

      it { should == @slug }
    end

    describe 'with an argument' do
      subject { @operation.class.slug(:other) }

      it { should == :other }

      # reset the AndOperation slug
      after { @operation.class.slug(@slug) }
    end
  end

  it { should respond_to(:==) }

  describe '#==' do
    describe 'when the other AbstractOperation is equal' do
      # artifically modify the object so #eql? will throw an
      # exception if the equal? branch is not followed when heckling
      before { @operation.meta_class.send(:undef_method, :slug) }

      subject { @operation == @operation }

      it { should be_true }
    end

    describe 'when the other AbstractOperation is the same class' do
      subject { @operation == DataMapper::Query::Conditions::Operation.new(@slug) }

      it { should be_true }
    end

    describe 'when the other AbstractOperation is a different class, with the same slug' do
      before { @other.class.slug(@slug) }

      subject { @operation == @other }

      it { should be_true }

      # reset the OtherOperation slug
      after { @other.class.slug(:other) }
    end

    describe 'when the other AbstractOperation is the same class, with different operands' do
      subject { @operation == DataMapper::Query::Conditions::Operation.new(@slug, @comparison) }

      it { should be_false }
    end
  end

  it { should respond_to(:children) }

  describe '#children' do
    subject { @operation.children }

    it { should be_kind_of(Set) }

    it { should be_empty }

    it { should equal(@operation.operands) }
  end

  it { should respond_to(:clear) }

  describe '#clear' do
    before do
      @operation << @other
      @operation.should_not be_empty
    end

    subject { @operation.clear }

    it { should equal(@operation) }

    it 'should clear the operands' do
      subject.should be_empty
    end
  end

  it { should respond_to(:dup) }

  describe '#dup' do
    subject { @operation.dup }

    it { should_not equal(@operation) }

    it { subject.to_a.should == @operation.to_a }
  end

  it { should respond_to(:each) }

  describe '#each' do
    before do
      @yield = []
      @operation << @other
    end

    subject { @operation.each { |operand| @yield << operand } }

    it { should equal(@operation) }

    it 'should yield to every operand' do
      subject
      @yield.should == [ @other ]
    end
  end

  it { should respond_to(:eql?) }

  describe '#eql?' do
    describe 'when the other AbstractOperation is equal' do
      # artifically modify the object so #eql? will throw an
      # exception if the equal? branch is not followed when heckling
      before { @operation.meta_class.send(:undef_method, :slug) }

      subject { @operation.eql?(@operation) }

      it { should be_true }
    end

    describe 'when the other AbstractOperation is the same class' do
      subject { @operation.eql?(DataMapper::Query::Conditions::Operation.new(@slug)) }

      it { should be_true }
    end

    describe 'when the other AbstractOperation is a different class' do
      subject { @operation.eql?(DataMapper::Query::Conditions::Operation.new(:other)) }

      it { should be_false }
    end

    describe 'when the other AbstractOperation is the same class, with different operands' do
      subject { @operation.eql?(DataMapper::Query::Conditions::Operation.new(@slug, @comparison)) }

      it { should be_false }
    end
  end

  it { should respond_to(:hash) }

  describe '#hash' do
    describe 'with operands' do
      before do
        @operation << @comparison
      end

      subject { @operation.hash }

      it 'should match the same AbstractOperation with the same operands' do
        should == DataMapper::Query::Conditions::Operation.new(@slug, @comparison.dup).hash
      end

      it 'should not match the same AbstractOperation with different operands' do
        should_not == DataMapper::Query::Conditions::Operation.new(@slug).hash
      end

      it 'should not match a different AbstractOperation with the same operands' do
        should_not == @other.class.new(@comparison.dup).hash
      end

      it 'should not match a different AbstractOperation with different operands' do
        should_not == DataMapper::Query::Conditions::Operation.new(:or).hash
      end
    end
  end

  it { should respond_to(:operands) }

  describe '#operands' do
    subject { @operation.operands }

    it { should be_kind_of(Set) }

    it { should be_empty }

    it { should equal(@operation.children) }
  end

  it { should respond_to(:parent) }

  describe '#parent' do
    describe 'when there is no parent' do
      subject { @operation.parent }

      it { should be_nil }
    end

    describe 'when there is a parent' do
      before { @other << @operation }

      subject { @operation.parent }

      it { should equal(@other) }
    end
  end

  it { should respond_to(:parent=) }

  describe '#parent=' do
    subject { @operation.parent = @other }

    it { should equal(@other) }

    it 'should change the parent' do
      method(:subject).should change(@operation, :parent).
        from(nil).
        to(@other)
    end
  end

  it { should respond_to(:valid?) }

  describe '#valid?' do
    subject { @operation.valid? }

    describe 'with no operands' do
      it { should be_false }
    end

    describe 'with an operand that responds to #valid?' do
      describe 'and is valid' do
        before do
          @operation << @comparison
        end

        it { should be_true }
      end

      describe 'and is not valid' do
        before do
          @operation << @or_operation
        end

        it { should be_false }
      end
    end

    describe 'with an operand that does not respond to #valid?' do
      before do
        @operation << [ 'raw = 1' ]
      end

      it { should be_true }
    end
  end
end

describe DataMapper::Query::Conditions::Operation do
  it { DataMapper::Query::Conditions::Operation.should respond_to(:new) }

  describe '.new' do
    {
      :and  => DataMapper::Query::Conditions::AndOperation,
      :or   => DataMapper::Query::Conditions::OrOperation,
      :not  => DataMapper::Query::Conditions::NotOperation,
      :null => DataMapper::Query::Conditions::NullOperation,
    }.each do |slug, klass|
      describe "with a slug #{slug.inspect}" do
        subject { DataMapper::Query::Conditions::Operation.new(slug) }

        it { should be_kind_of(klass) }

        it { subject.should be_empty }
      end
    end

    describe 'with an invalid slug' do
      subject { DataMapper::Query::Conditions::Operation.new(:invalid) }

      it { method(:subject).should raise_error(ArgumentError) }
    end

    describe 'with operands' do
      before { @or_operation = DataMapper::Query::Conditions::Operation.new(:or) }

      subject { DataMapper::Query::Conditions::Operation.new(:and, @or_operation) }

      it { should be_kind_of(DataMapper::Query::Conditions::AndOperation) }

      it 'should set the operands' do
        subject.to_a.should == [ @or_operation ]
      end
    end
  end

  it { DataMapper::Query::Conditions::Operation.should respond_to(:operation_class) }

  describe '.operation_class' do
    describe 'with a known slug' do
      subject { DataMapper::Query::Conditions::Operation.operation_class(:and) }

      it { should equal(DataMapper::Query::Conditions::AndOperation) }
    end

    describe 'with a unknown slug' do
      subject { DataMapper::Query::Conditions::Operation.operation_class(:unknown) }

      it { should be_nil }
    end
  end
end

describe DataMapper::Query::Conditions::AndOperation do
  it_should_behave_like 'DataMapper::Query::Conditions::AbstractOperation'

  before do
    @operation = @and_operation
    @slug      = @operation.slug
  end

  it { should respond_to(:<<) }

  describe '#<<' do
    describe 'with an AndOperation' do
      subject { @operation << @and_operation.class.new(@comparison) }

      it { should equal(@operation) }

      it 'should flatten and merge the AndOperation operand' do
        subject.to_a.should == [ @comparison ]
      end

      it 'should set the parent for the operand' do
        subject.each { |operand| operand.parent.should equal(@operation) }
      end
    end

    describe 'with an OrOperation' do
      subject { @operation << @or_operation.class.new(@comparison) }

      it { should equal(@operation) }

      it 'should merge the operand' do
        subject.to_a.should == [ @or_operation.class.new(@comparison) ]
      end

      it 'should set the parent for the operand' do
        subject.each { |operand| operand.parent.should equal(@operation) }
      end
    end

    describe 'with a NotOperation' do
      subject { @operation << @not_operation.class.new(@comparison) }

      it { should equal(@operation) }

      it 'should merge the operand' do
        subject.to_a.should == [ @not_operation.class.new(@comparison) ]
      end

      it 'should set the parent for the operand' do
        subject.each { |operand| operand.parent.should equal(@operation) }
      end
    end

    describe 'with a NullOperation' do
      subject { @operation << @null_operation }

      it { should equal(@operation) }

      it 'should not merge the operand' do
        subject.to_a.should == []
      end
    end

    describe 'with a duplicate operand' do
      before { @operation << @comparison.dup }

      subject { @operation << @comparison.dup }

      it { should equal(@operation) }

      it 'should have unique operands' do
        subject.to_a.should == [ @comparison ]
      end

      it 'should set the parent for the operand' do
        subject.each { |operand| operand.parent.should equal(@operation) }
      end
    end

    describe 'with an invalid operand' do
      subject { @operation << '' }

      it { method(:subject).should raise_error(ArgumentError)  }
    end
  end

  it { should respond_to(:merge) }

  describe '#merge' do
    describe 'with an AndOperation' do
      subject { @operation.merge([ @and_operation.class.new(@comparison) ]) }

      it { should equal(@operation) }

      it 'should flatten and merge the AndOperation operands' do
        subject.to_a.should == [ @comparison ]
      end

      it 'should set the parent for each operand' do
        subject.each { |operand| operand.parent.should equal(@operation) }
      end
    end

    describe 'with an OrOperation' do
      subject { @operation.merge([ @or_operation.class.new(@comparison) ]) }

      it { should equal(@operation) }

      it 'should merge the operand' do
        subject.to_a.should == [ @or_operation.class.new(@comparison) ]
      end

      it 'should set the parent for each operand' do
        subject.each { |operand| operand.parent.should equal(@operation) }
      end
    end

    describe 'with a NotOperation' do
      subject { @operation.merge([ @not_operation.class.new(@comparison) ]) }

      it { should equal(@operation) }

      it 'should merge the operand' do
        subject.to_a.should == [ @not_operation.class.new(@comparison) ]
      end

      it 'should set the parent for each operand' do
        subject.each { |operand| operand.parent.should equal(@operation) }
      end
    end

    describe 'with a NullOperation' do
      subject { @operation.merge([ @null_operation ]) }

      it { should equal(@operation) }

      it 'should not merge the operand' do
        subject.to_a.should == []
      end
    end

    describe 'with a duplicate operand' do
      before { @operation << @comparison.dup }

      subject { @operation.merge([ @comparison.dup ]) }

      it { should equal(@operation) }

      it 'should have unique operands' do
        subject.to_a.should == [ @comparison ]
      end

      it 'should set the parent for each operand' do
        subject.each { |operand| operand.parent.should equal(@operation) }
      end
    end

    describe 'with an invalid operand' do
      subject { @operation.merge([ '' ]) }

      it { method(:subject).should raise_error(ArgumentError)  }
    end
  end

  it { should respond_to(:negated?) }

  describe '#negated?' do
    describe 'with a negated parent' do
      before do
        @not_operation.class.new(@operation)
      end

      subject { @operation.negated? }

      it { should be_true }
    end

    describe 'with a not negated parent' do
      before do
        @or_operation.class.new(@operation)
      end

      subject { @operation.negated? }

      it { should be_false }
    end

    describe 'after memoizing the negation, and switching parents' do
      before do
        @or_operation.class.new(@operation)
        @operation.should_not be_negated
        @not_operation.class.new(@operation)
      end

      subject { @operation.negated? }

      it { should be_true }
    end
  end

  it { should respond_to(:matches?) }

  describe '#matches?' do
    before do
      @operation << @comparison << @comparison.class.new(@model.properties[:id], 1)
    end

    supported_by :all do
      describe 'with a matching Hash' do
        subject { @operation.matches?('title' => 'A title', 'id' => 1) }

        it { should be_true }
      end

      describe 'with a not matching Hash' do
        subject { @operation.matches?('title' => 'Not matching', 'id' => 1) }

        it { should be_false }
      end

      describe 'with a matching Resource' do
        subject { @operation.matches?(@model.new(:title => 'A title', :id => 1)) }

        it { should be_true }
      end

      describe 'with a not matching Hash' do
        subject { @operation.matches?(@model.new(:title => 'Not matching', :id => 1)) }

        it { should be_false }
      end
    end
  end

  it { should respond_to(:to_s) }

  describe '#to_s' do
    describe 'with no operands' do
      subject { @operation.to_s }

      it { should be_kind_of(String) }

      it { should == '' }
    end

    describe 'with operands' do
      before do
        @not_operation << @comparison.dup
        @operation << @comparison << @not_operation
      end

      subject { @operation.to_s }

      it { should be_kind_of(String) }

      it { should == '(NOT(title = A title) AND title = A title)' }
    end
  end

  it { should respond_to(:valid?) }

  describe '#valid?' do
    describe 'with one valid operand, and one invalid operand' do
      before do
        @operation << @comparison
        @operation << DataMapper::Query::Conditions::Comparison.new(:in, @model.properties[:id], [])
      end

      subject { @operation.valid? }

      it { should be_false }
    end

    describe 'with one invalid operand' do
      before do
        @operation << DataMapper::Query::Conditions::Comparison.new(:in, @model.properties[:id], [])
      end

      subject { @operation.valid? }

      it { should be_false }
    end
  end
end

describe DataMapper::Query::Conditions::OrOperation do
  it_should_behave_like 'DataMapper::Query::Conditions::AbstractOperation'

  before do
    @operation = @or_operation
    @slug      = @operation.slug
  end

  it { should respond_to(:<<) }

  describe '#<<' do
    describe 'with an AndOperation' do
      subject { @operation << @and_operation.class.new(@comparison) }

      it { should equal(@operation) }

      it 'should merge the operand' do
        subject.to_a.should == [ @and_operation.class.new(@comparison) ]
      end

      it 'should set the parent for the operand' do
        subject.each { |operand| operand.parent.should equal(@operation) }
      end
    end

    describe 'with an OrOperation' do
      subject { @operation << @or_operation.class.new(@comparison) }

      it { should equal(@operation) }

      it 'should flatten and merge the OrOperation operand' do
        subject.to_a.should == [ @comparison ]
      end

      it 'should set the parent for the operand' do
        subject.each { |operand| operand.parent.should equal(@operation) }
      end
    end

    describe 'with a NotOperation' do
      subject { @operation << @not_operation.class.new(@comparison) }

      it { should equal(@operation) }

      it 'should merge the operand' do
        subject.to_a.should == [ @not_operation.class.new(@comparison) ]
      end

      it 'should set the parent for the operand' do
        subject.each { |operand| operand.parent.should equal(@operation) }
      end
    end

    describe 'with a NullOperation' do
      subject { @operation << @null_operation }

      it { should equal(@operation) }

      it 'should not merge the operand' do
        subject.to_a.should == []
      end
    end

    describe 'with a duplicate operand' do
      before { @operation << @comparison.dup }

      subject { @operation << @comparison.dup }

      it { should equal(@operation) }

      it 'should have unique operands' do
        subject.to_a.should == [ @comparison ]
      end

      it 'should set the parent for the operand' do
        subject.each { |operand| operand.parent.should equal(@operation) }
      end
    end

    describe 'with an invalid operand' do
      subject { @operation << '' }

      it { method(:subject).should raise_error(ArgumentError)  }
    end
  end

  it { should respond_to(:negated?) }

  describe '#negated?' do
    describe 'with a negated parent' do
      before do
        @not_operation.class.new(@operation)
      end

      subject { @operation.negated? }

      it { should be_true }
    end

    describe 'with a not negated parent' do
      before do
        @and_operation.class.new(@operation)
      end

      subject { @operation.negated? }

      it { should be_false }
    end

    describe 'after memoizing the negation, and switching parents' do
      before do
        @or_operation.class.new(@operation)
        @operation.should_not be_negated
        @not_operation.class.new(@operation)
      end

      subject { @operation.negated? }

      it { should be_true }
    end
  end

  it { should respond_to(:merge) }

  describe '#merge' do
    describe 'with an AndOperation' do
      subject { @operation.merge([ @and_operation.class.new(@comparison) ]) }

      it { should equal(@operation) }

      it 'should merge the operand' do
        subject.to_a.should == [ @and_operation.class.new(@comparison) ]
      end

      it 'should set the parent for each operand' do
        subject.each { |operand| operand.parent.should equal(@operation) }
      end
    end

    describe 'with an OrOperation' do
      subject { @operation.merge([ @or_operation.class.new(@comparison) ]) }

      it { should equal(@operation) }

      it 'should flatten and merge the OrOperation operand' do
        subject.to_a.should == [ @comparison ]
      end

      it 'should set the parent for each operand' do
        subject.each { |operand| operand.parent.should equal(@operation) }
      end
    end

    describe 'with a NotOperation' do
      subject { @operation.merge([ @not_operation.class.new(@comparison) ]) }

      it { should equal(@operation) }

      it 'should merge the operand' do
        subject.to_a.should == [ @not_operation.class.new(@comparison) ]
      end

      it 'should set the parent for each operand' do
        subject.each { |operand| operand.parent.should equal(@operation) }
      end
    end

    describe 'with a NullOperation' do
      subject { @operation.merge([ @null_operation ]) }

      it { should equal(@operation) }

      it 'should not merge the operand' do
        subject.to_a.should == []
      end
    end

    describe 'with a duplicate operand' do
      before { @operation << @comparison.dup }

      subject { @operation.merge([ @comparison.dup ]) }

      it { should equal(@operation) }

      it 'should have unique operands' do
        subject.to_a.should == [ @comparison ]
      end

      it 'should set the parent for each operand' do
        subject.each { |operand| operand.parent.should equal(@operation) }
      end
    end

    describe 'with an invalid operand' do
      subject { @operation.merge([ '' ]) }

      it { method(:subject).should raise_error(ArgumentError)  }
    end
  end

  it { should respond_to(:matches?) }

  describe '#matches?' do
    before do
      @operation << @comparison << @comparison.class.new(@model.properties[:id], 1)
    end

    supported_by :all do
      describe 'with a matching Hash' do
        subject { @operation.matches?('title' => 'A title', 'id' => 2) }

        it { should be_true }
      end

      describe 'with a not matching Hash' do
        subject { @operation.matches?('title' => 'Not matching', 'id' => 2) }

        it { should be_false }
      end

      describe 'with a matching Resource' do
        subject { @operation.matches?(@model.new(:title => 'A title', :id => 2)) }

        it { should be_true }
      end

      describe 'with a not matching Hash' do
        subject { @operation.matches?(@model.new(:title => 'Not matching', :id => 2)) }

        it { should be_false }
      end
    end
  end

  it { should respond_to(:valid?) }

  describe '#valid?' do
    describe 'with one valid operand, and one invalid operand' do
      before do
        @operation << @comparison
        @operation << DataMapper::Query::Conditions::Comparison.new(:in, @model.properties[:id], [])
      end

      subject { @operation.valid? }

      it { should be_true }
    end

    describe 'with one invalid operand' do
      before do
        @operation << DataMapper::Query::Conditions::Comparison.new(:in, @model.properties[:id], [])
      end

      subject { @operation.valid? }

      it { should be_false }
    end
  end
end

describe DataMapper::Query::Conditions::NotOperation do
  it_should_behave_like 'DataMapper::Query::Conditions::AbstractOperation'

  before do
    @operation = @not_operation
    @slug      = @operation.slug
  end

  it { should respond_to(:<<) }

  describe '#<<' do
    describe 'with an AndOperation' do
      subject { @operation << @and_operation.class.new(@comparison) }

      it { should equal(@operation) }

      it 'should merge the operand' do
        subject.to_a.should == [ @and_operation.class.new(@comparison) ]
      end

      it 'should set the parent for the operand' do
        subject.each { |operand| operand.parent.should equal(@operation) }
      end
    end

    describe 'with an OrOperation' do
      subject { @operation << @or_operation.class.new(@comparison) }

      it { should equal(@operation) }

      it 'should merge the operand' do
        subject.to_a.should == [ @or_operation.class.new(@comparison) ]
      end

      it 'should set the parent for the operand' do
        subject.each { |operand| operand.parent.should equal(@operation) }
      end
    end

    describe 'with a NotOperation' do
      subject { @operation << @not_operation.class.new(@comparison) }

      it { should equal(@operation) }

      it 'should merge the operand' do
        subject.to_a.should == [ @not_operation.class.new(@comparison) ]
      end

      it 'should set the parent for the operand' do
        subject.each { |operand| operand.parent.should equal(@operation) }
      end
    end

    describe 'with a NullOperation' do
      subject { @operation << @null_operation }

      it { should equal(@operation) }

      it 'should not merge the operand' do
        subject.to_a.should == []
      end
    end

    describe 'with a duplicate operand' do
      before { @operation << @comparison.dup }

      subject { @operation << @comparison.dup }

      it { should equal(@operation) }

      it 'should have unique operands' do
        subject.to_a.should == [ @comparison ]
      end

      it 'should set the parent for the operand' do
        subject.each { |operand| operand.parent.should equal(@operation) }
      end
    end

    describe 'with an invalid operand' do
      subject { @operation << '' }

      it { method(:subject).should raise_error(ArgumentError)  }
    end

    describe 'with more than one operand' do
      subject { @operation << @comparison << @other }

      it { method(:subject).should raise_error(ArgumentError)  }
    end
  end

  it { should respond_to(:negated?) }

  describe '#negated?' do
    describe 'with a negated parent' do
      before do
        @not_operation.class.new(@operation)
      end

      subject { @operation.negated? }

      it { should be_false }
    end

    describe 'with a not negated parent' do
      before do
        @or_operation.class.new(@operation)
      end

      subject { @operation.negated? }

      it { should be_true }
    end

    describe 'after memoizing the negation, and switching parents' do
      before do
        @or_operation.class.new(@operation)
        @operation.should be_negated
        @not_operation.class.new(@operation)
      end

      subject { @operation.negated? }

      it { should be_false }
    end
  end

  it { should respond_to(:merge) }

  describe '#merge' do
    describe 'with an AndOperation' do
      subject { @operation.merge([ @and_operation.class.new(@comparison) ]) }

      it { should equal(@operation) }

      it 'should merge the operand' do
        subject.to_a.should == [ @and_operation.class.new(@comparison) ]
      end

      it 'should set the parent for the operand' do
        subject.each { |operand| operand.parent.should equal(@operation) }
      end
    end

    describe 'with an OrOperation' do
      subject { @operation.merge([ @or_operation.class.new(@comparison) ]) }

      it { should equal(@operation) }

      it 'should merge the operand' do
        subject.to_a.should == [ @or_operation.class.new(@comparison) ]
      end

      it 'should set the parent for the operand' do
        subject.each { |operand| operand.parent.should equal(@operation) }
      end
    end

    describe 'with a NotOperation' do
      subject { @operation.merge([ @not_operation.class.new(@comparison) ]) }

      it { should equal(@operation) }

      it 'should merge the operand' do
        subject.to_a.should == [ @not_operation.class.new(@comparison) ]
      end

      it 'should set the parent for the operand' do
        subject.each { |operand| operand.parent.should equal(@operation) }
      end
    end

    describe 'with a NullOperation' do
      subject { @operation.merge([ @null_operation ]) }

      it { should equal(@operation) }

      it 'should not merge the operand' do
        subject.to_a.should == []
      end
    end

    describe 'with a duplicate operand' do
      before { @operation << @comparison.dup }

      subject { @operation.merge([ @comparison.dup ]) }

      it { should equal(@operation) }

      it 'should have unique operands' do
        subject.to_a.should == [ @comparison ]
      end

      it 'should set the parent for the operand' do
        subject.each { |operand| operand.parent.should equal(@operation) }
      end
    end

    describe 'with an invalid operand' do
      subject { @operation.merge([ '' ]) }

      it { method(:subject).should raise_error(ArgumentError)  }
    end

    describe 'with more than one operand' do
      subject { @operation.merge([ @comparison, @other ]) }

      it { method(:subject).should raise_error(ArgumentError)  }
    end
  end

  it { should respond_to(:matches?) }

  describe '#matches?' do
    before do
      @operation << @comparison.class.new(@model.properties[:id], 1)
    end

    supported_by :all do
      describe 'with a matching Hash' do
        subject { @operation.matches?('id' => 2) }

        it { should be_true }
      end

      describe 'with a not matching Hash' do
        subject { @operation.matches?('id' => 1) }

        it { should be_false }
      end

      describe 'with a matching Resource' do
        subject { @operation.matches?(@model.new(:id => 2)) }

        it { should be_true }
      end

      describe 'with a not matching Hash' do
        subject { @operation.matches?(@model.new(:id => 1)) }

        it { should be_false }
      end
    end
  end

  it { should respond_to(:to_s) }

  describe '#to_s' do
    describe 'with no operands' do
      subject { @operation.to_s }

      it { should be_kind_of(String) }

      it { should == '' }
    end

    describe 'with operands' do
      before do
        @operation << @comparison
      end

      subject { @operation.to_s }

      it { should be_kind_of(String) }

      it { should == 'NOT(title = A title)' }
    end
  end

  it { should respond_to(:valid?) }

  describe '#valid?' do
    describe 'with one invalid operand' do
      before do
        @operation << @not_operation.class.new(
          DataMapper::Query::Conditions::Comparison.new(:eql, @model.properties[:id], nil)
        )
      end

      subject { @operation.valid? }

      it { should be_false }
    end
  end
end

describe DataMapper::Query::Conditions::NullOperation do
  before :all do
    module ::Blog
      class Article
        include DataMapper::Resource

        property :id,    Serial
        property :title, String, :nullable => false
      end
    end

    @model = Blog::Article
  end

  before do
    @operation = DataMapper::Query::Conditions::Operation.new(:null)
    @slug      = @operation.slug
  end

  it { should respond_to(:slug) }

  describe '#slug' do
    subject { @operation.slug }

    it { should == :null }
  end

  it { should respond_to(:matches?) }

  describe '#matches?' do
    describe 'with a Hash' do
      subject { @operation.matches?({}) }

      it { should be_true }
    end

    describe 'with a Resource' do
      subject { @operation.matches?(Blog::Article.new) }

      it { should be_true }
    end

    describe 'with any other Object' do
      subject { @operation.matches?(Object.new) }

      it { should be_false }
    end
  end

  it { should respond_to(:valid?) }

  describe '#valid?' do
    subject { @operation.valid? }

    it { should be_true }
  end

  it { should respond_to(:nil?) }

  describe '#nil?' do
    subject { @operation.nil? }

    it { should be_true }
  end

  it { should respond_to(:inspect) }

  describe '#inspect' do
    subject { @operation.inspect }

    it { should == 'nil' }
  end
end
