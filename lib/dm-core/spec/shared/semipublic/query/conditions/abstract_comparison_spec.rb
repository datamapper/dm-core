shared_examples_for 'DataMapper::Query::Conditions::AbstractComparison' do
  before :all do
    module ::Blog
      class Article
        include DataMapper::Resource

        property :id,    Serial
        property :title, String, :required => true

        belongs_to :parent, self, :required => false
        has n, :children, self, :inverse => :parent
      end
    end

    DataMapper.finalize

    @model = Blog::Article
  end

  before do
    class ::OtherComparison < DataMapper::Query::Conditions::AbstractComparison
      slug :other
    end
  end

  before do
    @relationship = @model.relationships[:parent]
  end

  it { subject.class.should respond_to(:new) }

  describe '.new' do
    subject { @comparison.class.new(@property, @value) }

    it { should be_kind_of(@comparison.class) }

    it { subject.subject.should equal(@property) }

    it { subject.value.should == @value }
  end

  it { subject.class.should respond_to(:slug) }

  describe '.slug' do
    describe 'with no arguments' do
      subject { @comparison.class.slug }

      it { should == @slug }
    end

    describe 'with an argument' do
      subject { @comparison.class.slug(:other) }

      it { should == :other }

      # reset the slug
      after { @comparison.class.slug(@slug) }
    end
  end

  it { should respond_to(:==) }

  describe '#==' do
    describe 'when the other AbstractComparison is equal' do
      # artificially modify the object so #== will throw an
      # exception if the equal? branch is not followed when heckling
      before { @comparison.singleton_class.send(:undef_method, :slug) }

      subject { @comparison == @comparison }

      it { should be(true) }
    end

    describe 'when the other AbstractComparison is the same class' do
      subject { @comparison == DataMapper::Query::Conditions::Comparison.new(@slug, @property, @value) }

      it { should be(true) }
    end

    describe 'when the other AbstractComparison is a different class' do
      subject { @comparison == DataMapper::Query::Conditions::Comparison.new(:other, @property, @value) }

      it { should be(false) }
    end

    describe 'when the other AbstractComparison is the same class, with different property' do
      subject { @comparison == DataMapper::Query::Conditions::Comparison.new(@slug, @other_property, @value) }

      it { should be(false) }
    end

    describe 'when the other AbstractComparison is the same class, with different value' do
      subject { @comparison == DataMapper::Query::Conditions::Comparison.new(@slug, @property, @other_value) }

      it { should be(false) }
    end
  end

  it { should respond_to(:eql?) }

  describe '#eql?' do
    describe 'when the other AbstractComparison is equal' do
      # artificially modify the object so #eql? will throw an
      # exception if the equal? branch is not followed when heckling
      before { @comparison.singleton_class.send(:undef_method, :slug) }

      subject { @comparison.eql?(@comparison) }

      it { should be(true) }
    end

    describe 'when the other AbstractComparison is the same class' do
      subject { @comparison.eql?(DataMapper::Query::Conditions::Comparison.new(@slug, @property, @value)) }

      it { should be(true) }
    end

    describe 'when the other AbstractComparison is a different class' do
      subject { @comparison.eql?(DataMapper::Query::Conditions::Comparison.new(:other, @property, @value)) }

      it { should be(false) }
    end

    describe 'when the other AbstractComparison is the same class, with different property' do
      subject { @comparison.eql?(DataMapper::Query::Conditions::Comparison.new(@slug, @other_property, @value)) }

      it { should be(false) }
    end

    describe 'when the other AbstractComparison is the same class, with different value' do
      subject { @comparison.eql?(DataMapper::Query::Conditions::Comparison.new(@slug, @property, @other_value)) }

      it { should be(false) }
    end
  end

  it { should respond_to(:hash) }

  describe '#hash' do
    subject { @comparison.hash }

    it 'should match the same AbstractComparison with the same property and value' do
      should == DataMapper::Query::Conditions::Comparison.new(@slug, @property, @value).hash
    end

    it 'should not match the same AbstractComparison with different property' do
      should_not == DataMapper::Query::Conditions::Comparison.new(@slug, @other_property, @value).hash
    end

    it 'should not match the same AbstractComparison with different value' do
      should_not == DataMapper::Query::Conditions::Comparison.new(@slug, @property, @other_value).hash
    end

    it 'should not match a different AbstractComparison with the same property and value' do
      should_not == @other.hash
    end

    it 'should not match a different AbstractComparison with different property' do
      should_not == @other.class.new(@other_property, @value).hash
    end

    it 'should not match a different AbstractComparison with different value' do
      should_not == @other.class.new(@property, @other_value).hash
    end
  end

  it { should respond_to(:loaded_value) }

  describe '#loaded_value' do
    subject { @comparison.loaded_value }

    it { should == @value }
  end

  it { should respond_to(:parent) }

  describe '#parent' do
    subject { @comparison.parent }

    describe 'should be nil by default' do
      it { should be_nil }
    end

    describe 'should relate to parent operation' do
      before do
        @operation = DataMapper::Query::Conditions::Operation.new(:and)
        @comparison.parent = @operation
      end

      it { should be_equal(@operation) }
    end
  end

  it { should respond_to(:parent=) }

  describe '#parent=' do
    before do
      @operation = DataMapper::Query::Conditions::Operation.new(:and)
    end

    subject { @comparison.parent = @operation }

    it { should equal(@operation) }

    it 'should change the parent' do
      method(:subject).should change(@comparison, :parent).
        from(nil).
        to(@operation)
    end
  end

  it { should respond_to(:property?) }

  describe '#property?' do
    subject { @comparison.property? }

    it { should be(true) }
  end

  it { should respond_to(:slug) }

  describe '#slug' do
    subject { @comparison.slug }

    it { should == @slug }
  end

  it { should respond_to(:subject) }

  describe '#subject' do
    subject { @comparison.subject }

    it { should be_equal(@property) }
  end

  it { should respond_to(:valid?) }

  describe '#valid?' do
    subject { @comparison.valid? }

    describe 'when the value is valid for the subject' do
      it { should be(true) }
    end

    describe 'when the value is not valid for the subject' do
      before do
        @comparison = DataMapper::Query::Conditions::Comparison.new(@slug, @property, nil)
      end

      it { should be(false) }
    end
  end

  it { should respond_to(:value) }

  describe '#value' do
    subject { @comparison.value }

    it { should == @value }
  end
end
