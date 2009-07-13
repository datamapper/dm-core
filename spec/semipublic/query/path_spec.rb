require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'spec_helper'))

# class methods
describe DataMapper::Query::Path do
  before :all do
    class ::Author
      include DataMapper::Resource

      property :id,    Serial
      property :title, String

      has n, :articles
    end

    class ::Article
      include DataMapper::Resource

      property :id,    Serial
      property :title, String

      belongs_to :author
    end

    @relationship  = Author.relationships[:articles]
    @relationships = [ @relationship ]
    @property      = Article.properties[:title]
  end

  it { DataMapper::Query::Path.should respond_to(:new) }

  describe '.new' do
    describe 'when supplied an Array of Relationships' do
      before do
        @path = DataMapper::Query::Path.new(@relationships)
      end

      it 'should return a Query::Path' do
        @path.should be_kind_of(DataMapper::Query::Path)
      end

      it 'should set Query::Path#relationships' do
        @path.relationships.should eql(@relationships)
      end

      it 'should copy the relationships' do
        @path.relationships.should_not equal(@relationships)
      end
    end

    describe 'when supplied an Array of Relationships and a Property Symbol name' do
      before do
        @path = DataMapper::Query::Path.new(@relationships, @property.name)
      end

      it 'should return a Query::Path' do
        @path.should be_kind_of(DataMapper::Query::Path)
      end

      it 'should set Query::Path#relationships' do
        @path.relationships.should eql(@relationships)
      end

      it 'should copy the relationships' do
        @path.relationships.should_not equal(@relationships)
      end

      it 'should set Query::Path#property' do
        @path.property.should equal(@property)
      end
    end

    describe 'when supplied an unknown property' do
      it 'should raise an error' do
        lambda { DataMapper::Query::Path.new(@relationships, :unknown) }.should raise_error(ArgumentError, "Unknown property 'unknown' in Article")
      end
    end
  end
end

# instance methods
describe DataMapper::Query::Path do
  before :all do
    class ::Author
      include DataMapper::Resource

      property :id,    Serial
      property :title, String

      has n, :articles
    end

    class ::Article
      include DataMapper::Resource

      property :id,    Serial
      property :title, String

      belongs_to :author
    end

    @relationship  = Author.relationships[:articles]
    @relationships = [ @relationship ]
    @property      = Article.properties[:title]

    @path = DataMapper::Query::Path.new(@relationships)
  end

  it { @path.should respond_to(:==) }

  describe '#==' do
    describe 'when other Query::Path is the same' do
      before do
        @other = @path

        @return = @path == @other
      end

      it 'should return true' do
        @return.should be_true
      end
    end

    describe 'when other Query::Path does not respond to #relationships' do
      before do
        class << @other = @path.dup
          undef_method :relationships
        end

        @return = @path == @other
      end

      it 'should return false' do
        @return.should be_false
      end
    end

    describe 'when other Query::Path does not respond to #property' do
      before do
        class << @other = @path.dup
          undef_method :property
        end

        @return = @path == @other
      end

      it 'should return false' do
        @return.should be_false
      end
    end

    describe 'when other Query::Path has different relationships' do
      before do
        @other = DataMapper::Query::Path.new([ Article.relationships[:author] ])

        @return = @path == @other
      end

      it 'should return false' do
        @return.should be_false
      end
    end

    describe 'when other Query::Path has different properties' do
      before do
        @other = DataMapper::Query::Path.new(@path.relationships, :title)

        @return = @path == @other
      end

      it 'should return false' do
        @return.should be_false
      end
    end

    describe 'when other Query::Path has the same relationship and property' do
      before do
        @other = DataMapper::Query::Path.new(@path.relationships, @path.property)

        @return = @path == @other
      end

      it 'should return true' do
        @return.should be_true
      end
    end
  end

  it { @path.should respond_to(:eql?) }

  describe '#eql?' do
    describe 'when other Query::Path is the same' do
      before do
        @other = @path

        @return = @path.eql?(@other)
      end

      it 'should return true' do
        @return.should be_true
      end
    end

    describe 'when other Object is not an instance of Query::Path' do
      before do
        class MyQueryPath < DataMapper::Query::Path; end

        @other = MyQueryPath.new(@path.relationships, @path.property)

        @return = @path.eql?(@other)
      end

      it 'should return false' do
        @return.should be_false
      end
    end

    describe 'when other Query::Path has different relationships' do
      before do
        @other = DataMapper::Query::Path.new([ Article.relationships[:author] ])

        @return = @path.eql?(@other)
      end

      it 'should return false' do
        @return.should be_false
      end
    end

    describe 'when other Query::Path has different properties' do
      before do
        @other = DataMapper::Query::Path.new(@path.relationships, :title)

        @return = @path.eql?(@other)
      end

      it 'should return false' do
        @return.should be_false
      end
    end

    describe 'when other Query::Path has the same relationship and property' do
      before do
        @other = DataMapper::Query::Path.new(@path.relationships, @path.property)

        @return = @path.eql?(@other)
      end

      it 'should return true' do
        @return.should be_true
      end
    end
  end

  it { @path.should respond_to(:model) }

  describe '#model' do
    it 'should return a Model' do
      @path.model.should be_kind_of(DataMapper::Model)
    end

    it 'should return expected value' do
      @path.model.should eql(Article)
    end
  end

  it { @path.should respond_to(:property) }

  describe '#property' do
    describe 'when no property is defined' do
      it 'should return nil' do
        @path.property.should be_nil
      end
    end

    describe 'when a property is defined' do
      before do
        @path = @path.class.new(@path.relationships, @property.name)
      end

      it 'should return a Property' do
        @path.property.should be_kind_of(DataMapper::Property)
      end

      it 'should return expected value' do
        @path.property.should eql(@property)
      end
    end
  end

  it { @path.should respond_to(:relationships) }

  describe '#relationships' do
    it 'should return an Array' do
      @path.relationships.should be_kind_of(Array)
    end

    it 'should return expected value' do
      @path.relationships.should eql(@relationships)
    end
  end

  it { @path.should respond_to(:respond_to?) }

  describe '#respond_to?' do
    describe 'when supplied a method name provided by the parent class' do
      before do
        @return = @path.respond_to?(:class)
      end

      it 'should return true' do
        @return.should be_true
      end
    end

    describe 'when supplied a method name provided by the property' do
      before do
        @path = @path.class.new(@path.relationships, @property.name)

        @return = @path.respond_to?(:instance_variable_name)
      end

      it 'should return true' do
        @return.should be_true
      end
    end

    describe 'when supplied a method name referring to a relationship' do
      before do
        @return = @path.respond_to?(:author)
      end

      it 'should return true' do
        @return.should be_true
      end
    end

    describe 'when supplied a method name referring to a property' do
      before do
        @return = @path.respond_to?(:title)
      end

      it 'should return true' do
        @return.should be_true
      end
    end

    describe 'when supplied an unknown method name' do
      before do
        @return = @path.respond_to?(:unknown)
      end

      it 'should return false' do
        @return.should be_false
      end
    end
  end

  it { @path.should respond_to(:repository_name) }

  describe '#repository_name' do
    it 'should return a Symbol' do
      @path.repository_name.should be_kind_of(Symbol)
    end

    it 'should return expected value' do
      @path.repository_name.should eql(:default)
    end
  end

  describe '#method_missing' do
    describe 'when supplied a method name provided by the parent class' do
      before do
        @return = @path.class
      end

      it 'should return the expected value' do
        @return.should eql(DataMapper::Query::Path)
      end
    end

    describe 'when supplied a method name provided by the property' do
      before do
        @path = @path.class.new(@path.relationships, @property.name)

        @return = @path.instance_variable_name
      end

      it 'should return the expected value' do
        @return.should eql('@title')
      end
    end

    describe 'when supplied a method name referring to a relationship' do
      before do
        @return = @path.author
      end

      it 'should return a Query::Path' do
        @return.should be_kind_of(DataMapper::Query::Path)
      end

      it 'should return the expected value' do
        @return.should eql(DataMapper::Query::Path.new([ @relationship, Article.relationships[:author] ]))
      end
    end

    describe 'when supplied a method name referring to a property' do
      before do
        @return = @path.title
      end

      it 'should return a Query::Path' do
        @return.should be_kind_of(DataMapper::Query::Path)
      end

      it 'should return the expected value' do
        @return.should eql(DataMapper::Query::Path.new(@relationships, :title))
      end
    end

    describe 'when supplied an unknown method name' do
      it 'should raise an error' do
        lambda { @path.unknown }.should raise_error(NoMethodError, "undefined property or relationship 'unknown' on Article")
      end
    end
  end

  ((DataMapper::Query::Conditions::Comparison.slugs | [ :not ]) - [ :eql, :in ]).each do |slug|
    describe "##{slug}" do
      before do
        @return = @path.send(slug)
      end

      it 'should return a Query::Operator' do
        @return.should be_kind_of(DataMapper::Query::Operator)
      end

      it 'should return expected value' do
        @return.should eql(DataMapper::Query::Operator.new(@path, slug))
      end
    end
  end
end
