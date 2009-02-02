require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

# TODO: make some of specs for Query.new shared.  the assertions and
# normalizations should happen for Query#update, Query#relative and
# Query#merge and should probably be in shared specs

# class methods
describe DataMapper::Query do
  before do
    class ::User
      include DataMapper::Resource

      property :name, String, :key => true

      belongs_to :referrer, :model => self
    end

    @repository = DataMapper::Repository.new(:default)
    @model      = User

    @fields       = [ :name ].freeze
    @links        = [ :referrer ].freeze
    @conditions   = { :name => 'Dan Kubb' }.freeze
    @offset       = 0
    @limit        = 1
    @order        = [ :name ].freeze
    @unique       = false
    @add_reversed = false
    @reload       = false

    @options = {
      :fields       => @fields,
      :links        => @links,
      :conditions   => @conditions,
      :offset       => @offset,
      :limit        => @limit,
      :order        => @order,
      :unique       => @unique,
      :add_reversed => @add_reversed,
      :reload       => @reload,
    }
  end

  it 'should respond to .new' do
    DataMapper::Query.should respond_to(:new)
  end

  describe '.new' do
    describe 'with a repository' do
      describe 'that is valid' do
        before do
          @return = @query = DataMapper::Query.new(@repository, @model, @options.freeze)
        end

        it 'should return a Query' do
          @return.should be_kind_of(DataMapper::Query)
        end

        it 'should set the repository' do
          @query.repository.should == @repository
        end
      end

      describe 'that is invalid' do
        it 'should raise an exception' do
          lambda {
            DataMapper::Query.new('invalid', @model, @options)
          }.should raise_error(ArgumentError, '+repository+ should be DataMapper::Repository, but was String')
        end
      end
    end

    describe 'with a model' do
      describe 'that is valid' do
        before do
          @return = @query = DataMapper::Query.new(@repository, @model, @options.freeze)
        end

        it 'should return a Query' do
          @return.should be_kind_of(DataMapper::Query)
        end

        it 'should set the model' do
          @query.model.should == @model
        end
      end

      describe 'that is invalid' do
        it 'should raise an exception' do
          lambda {
            DataMapper::Query.new(@repository, 'invalid', @options)
          }.should raise_error(ArgumentError, '+model+ should be DataMapper::Model, but was String')
        end
      end
    end

    describe 'with a fields option' do
      describe 'that is an Array containing a Symbol' do
        before do
          @return = @query = DataMapper::Query.new(@repository, @model, @options.freeze)
        end

        it 'should return a Query' do
          @return.should be_kind_of(DataMapper::Query)
        end

        it 'should set the fields' do
          @query.fields.should == @model.properties.values_at(*@fields)
        end
      end

      describe 'that is an Array containing a String' do
        before do
          @options[:fields] = [ 'name' ]

          @return = @query = DataMapper::Query.new(@repository, @model, @options.freeze)
        end

        it 'should return a Query' do
          @return.should be_kind_of(DataMapper::Query)
        end

        it 'should set the fields' do
          @query.fields.should == @model.properties.values_at('name')
        end
      end

      describe 'that is an Array containing a Property' do
        before do
          @options[:fields] = @model.properties.values_at(:name)

          @return = @query = DataMapper::Query.new(@repository, @model, @options.freeze)
        end

        it 'should return a Query' do
          @return.should be_kind_of(DataMapper::Query)
        end

        it 'should set the fields' do
          @query.fields.should == @model.properties.values_at(:name)
        end
      end

      describe 'that is missing' do
        before do
          @return = @query = DataMapper::Query.new(@repository, @model, @options.except(:fields).freeze)
        end

        it 'should return a Query' do
          @return.should be_kind_of(DataMapper::Query)
        end

        it 'should set fields to the model default properties' do
          @query.fields.should == @model.properties.defaults
        end
      end

      describe 'that is invalid' do
        it 'should raise an exception' do
          lambda {
            DataMapper::Query.new(@repository, @model, @options.update(:fields => :name))
          }.should raise_error(ArgumentError, '+options[:fields]+ should be Array, but was Symbol')
        end
      end

      describe 'that is an empty Array and the unique option is false' do
        it 'should raise an exception' do
          lambda {
            DataMapper::Query.new(@repository, @model, @options.update(:fields => [], :unique => false))
          }.should raise_error(ArgumentError, '+options[:fields]+ should not be empty if +options[:unique]+ is false')
        end
      end

      describe 'that is an Array containing an unknown Symbol' do
        it 'should raise an exception' do
          lambda {
            DataMapper::Query.new(@repository, @model, @options.update(:fields => [ :unknown ]))
          }.should raise_error(ArgumentError, '+options[:fields]+ entry :unknown does not map to a property')
        end
      end

      describe 'that is an Array containing an unknown String' do
        it 'should raise an exception' do
          lambda {
            DataMapper::Query.new(@repository, @model, @options.update(:fields => [ 'unknown' ]))
          }.should raise_error(ArgumentError, '+options[:fields]+ entry "unknown" does not map to a property')
        end
      end

      describe 'that is an Array containing an invalid object' do
        it 'should raise an exception' do
          lambda {
            DataMapper::Query.new(@repository, @model, @options.update(:fields => [ 1 ]))
          }.should raise_error(ArgumentError, '+options[:fields]+ entry 1 of an unsupported object Fixnum')
        end
      end
    end

    describe 'with a links option' do
      describe 'that is an Array containing a Symbol' do
        before do
          @return = @query = DataMapper::Query.new(@repository, @model, @options.freeze)
        end

        it 'should return a Query' do
          @return.should be_kind_of(DataMapper::Query)
        end

        it 'should set the links' do
          @query.links.should == @model.relationships.values_at(*@links)
        end
      end

      describe 'that is an Array containing a String' do
        before do
          @options[:links] = [ 'referrer' ]

          @return = @query = DataMapper::Query.new(@repository, @model, @options.freeze)
        end

        it 'should return a Query' do
          @return.should be_kind_of(DataMapper::Query)
        end

        it 'should set the links' do
          @query.links.should == @model.relationships.values_at('referrer')
        end
      end

      describe 'that is an Array containing a Relationship' do
        before do
          @options[:links] = @model.relationships.values_at(:referrer)

          @return = @query = DataMapper::Query.new(@repository, @model, @options.freeze)
        end

        it 'should return a Query' do
          @return.should be_kind_of(DataMapper::Query)
        end

        it 'should set the links' do
          @query.links.should == @model.relationships.values_at(:referrer)
        end
      end

      describe 'that is missing' do
        before do
          @return = @query = DataMapper::Query.new(@repository, @model, @options.except(:links).freeze)
        end

        it 'should return a Query' do
          @return.should be_kind_of(DataMapper::Query)
        end

        it 'should set links to an empty Array' do
          @query.links.should == []
        end
      end

      describe 'that is invalid' do
        it 'should raise an exception' do
          lambda {
            DataMapper::Query.new(@repository, @model, @options.update(:links => :referral))
          }.should raise_error(ArgumentError, '+options[:links]+ should be Array, but was Symbol')
        end
      end

      describe 'that is an empty Array' do
        it 'should raise an exception' do
          lambda {
            DataMapper::Query.new(@repository, @model, @options.update(:links => []))
          }.should raise_error(ArgumentError, '+options[:links]+ should not be empty')
        end
      end

      describe 'that is an Array containing an unknown Symbol' do
        it 'should raise an exception' do
          lambda {
            DataMapper::Query.new(@repository, @model, @options.update(:links => [ :unknown ]))
          }.should raise_error(ArgumentError, '+options[:links]+ entry :unknown does not map to a relationship')
        end
      end

      describe 'that is an Array containing an unknown String' do
        it 'should raise an exception' do
          lambda {
            DataMapper::Query.new(@repository, @model, @options.update(:links => [ 'unknown' ]))
          }.should raise_error(ArgumentError, '+options[:links]+ entry "unknown" does not map to a relationship')
        end
      end

      describe 'that is an Array containing an invalid object' do
        it 'should raise an exception' do
          lambda {
            DataMapper::Query.new(@repository, @model, @options.update(:links => [ 1 ]))
          }.should raise_error(ArgumentError, '+options[:links]+ entry 1 of an unsupported object Fixnum')
        end
      end
    end

    describe 'with a conditions option' do
      describe 'that is a valid Hash' do
        before do
          @return = @query = DataMapper::Query.new(@repository, @model, @options.freeze)
        end

        it 'should return a Query' do
          @return.should be_kind_of(DataMapper::Query)
        end

        it 'should set the conditions' do
          @query.conditions.should == [ [ :eql, @model.properties[:name], @conditions[:name] ] ]
        end
      end

      describe 'that is a valid Array' do
        before do
          @options[:conditions] = [ 'name = ?', 'Dan Kubb' ]

          @return = @query = DataMapper::Query.new(@repository, @model, @options.freeze)
        end

        it 'should return a Query' do
          @return.should be_kind_of(DataMapper::Query)
        end

        it 'should set the conditions' do
          @query.conditions.should == [ [ :raw, 'name = ?', 'Dan Kubb' ] ]
        end
      end

      describe 'that is missing' do
        before do
          @return = @query = DataMapper::Query.new(@repository, @model, @options.except(:conditions).freeze)
        end

        it 'should return a Query' do
          @return.should be_kind_of(DataMapper::Query)
        end

        it 'should set conditions to an empty Array' do
          @query.conditions.should == []
        end
      end

      describe 'that is invalid' do
        it 'should raise an exception' do
          lambda {
            DataMapper::Query.new(@repository, @model, @options.update(:conditions => 'invalid'))
          }.should raise_error(ArgumentError, '+options[:conditions]+ should be Hash or Array, but was String')
        end
      end

      describe 'that is an empty Array' do
        it 'should raise an exception' do
          lambda {
            DataMapper::Query.new(@repository, @model, @options.update(:conditions => []))
          }.should raise_error(ArgumentError, '+options[:conditions]+ should not be empty')
        end
      end
    end

    describe 'with an offset option' do
      describe 'that is valid' do
        before do
          @return = @query = DataMapper::Query.new(@repository, @model, @options.freeze)
        end

        it 'should return a Query' do
          @return.should be_kind_of(DataMapper::Query)
        end

        it 'should set the offset' do
          @query.offset.should == @offset
        end
      end

      describe 'that is missing' do
        before do
          @return = @query = DataMapper::Query.new(@repository, @model, @options.except(:offset).freeze)
        end

        it 'should return a Query' do
          @return.should be_kind_of(DataMapper::Query)
        end

        it 'should set offset to 0' do
          @query.offset.should == 0
        end
      end

      describe 'that is invalid' do
        it 'should raise an exception' do
          lambda {
            DataMapper::Query.new(@repository, @model, @options.update(:offset => '0'))
          }.should raise_error(ArgumentError, '+options[:offset]+ should be Integer, but was String')
        end
      end

      describe 'that is less than 0' do
        it 'should raise an exception' do
          lambda {
            DataMapper::Query.new(@repository, @model, @options.update(:offset => -1))
          }.should raise_error(ArgumentError, '+options[:offset]+ must be greater than or equal to 0, but was -1')
        end
      end
    end

    describe 'with a limit option' do
      describe 'that is valid' do
        before do
          @return = @query = DataMapper::Query.new(@repository, @model, @options.freeze)
        end

        it 'should return a Query' do
          @return.should be_kind_of(DataMapper::Query)
        end

        it 'should set the limit' do
          @query.limit.should == @limit
        end
      end

      describe 'that is missing' do
        before do
          @return = @query = DataMapper::Query.new(@repository, @model, @options.except(:limit).freeze)
        end

        it 'should return a Query' do
          @return.should be_kind_of(DataMapper::Query)
        end

        it 'should set limit to nil' do
          @query.limit.should be_nil
        end
      end

      describe 'that is invalid' do
        it 'should raise an exception' do
          lambda {
            DataMapper::Query.new(@repository, @model, @options.update(:limit => '1'))
          }.should raise_error(ArgumentError, '+options[:limit]+ should be Integer, but was String')
        end
      end

      describe 'that is less than 1' do
        it 'should raise an exception' do
          lambda {
            DataMapper::Query.new(@repository, @model, @options.update(:limit => 0))
          }.should raise_error(ArgumentError, '+options[:limit]+ must be greater than or equal to 1, but was 0')
        end
      end
    end

    describe 'with an order option' do
      describe 'that is an Array containing a Symbol' do
        before do
          @return = @query = DataMapper::Query.new(@repository, @model, @options.freeze)
        end

        it 'should return a Query' do
          @return.should be_kind_of(DataMapper::Query)
        end

        it 'should set the order' do
          @query.order.should == [ DataMapper::Query::Direction.new(@model.properties[:name]) ]
        end
      end

      describe 'that is an Array containing a String' do
        before do
          @options[:order] = [ 'name' ]

          @return = @query = DataMapper::Query.new(@repository, @model, @options.freeze)
        end

        it 'should return a Query' do
          @return.should be_kind_of(DataMapper::Query)
        end

        it 'should set the order' do
          @query.order.should == [ DataMapper::Query::Direction.new(@model.properties[:name]) ]
        end
      end

      describe 'that is an Array containing a Property' do
        before do
          @options[:order] = @model.properties.values_at(:name)

          @return = @query = DataMapper::Query.new(@repository, @model, @options.freeze)
        end

        it 'should return a Query' do
          @return.should be_kind_of(DataMapper::Query)
        end

        it 'should set the order' do
          @query.order.should == [ DataMapper::Query::Direction.new(@model.properties[:name]) ]
        end
      end

      describe 'that is an Array containing an Operator' do
        before do
          @options[:order] = [ :name.desc ]

          @return = @query = DataMapper::Query.new(@repository, @model, @options.freeze)
        end

        it 'should return a Query' do
          @return.should be_kind_of(DataMapper::Query)
        end

        it 'should set the order' do
          @query.order.should == [ DataMapper::Query::Direction.new(@model.properties[:name], :desc) ]
        end
      end

      describe 'that is missing' do
        before do
          @return = @query = DataMapper::Query.new(@repository, @model, @options.except(:order).freeze)
        end

        it 'should return a Query' do
          @return.should be_kind_of(DataMapper::Query)
        end

        it 'should set order to the model default order' do
          @query.order.should == @model.default_order(@repository.name)
        end
      end

      describe 'that is invalid' do
        it 'should raise an exception' do
          lambda {
            DataMapper::Query.new(@repository, @model, @options.update(:order => :name))
          }.should raise_error(ArgumentError, '+options[:order]+ should be Array, but was Symbol')
        end
      end

      describe 'that is an empty Array and the fields option contains a non-operator' do
        it 'should raise an exception' do
          lambda {
            DataMapper::Query.new(@repository, @model, @options.update(:order => [], :fields => [ :name ]))
          }.should raise_error(ArgumentError, '+options[:order]+ should not be empty if +options[:fields] contains a non-operator')
        end
      end

      describe 'that is an Array containing an unknown String' do
        it 'should raise an exception' do
          lambda {
            DataMapper::Query.new(@repository, @model, @options.update(:order => [ 'unknown' ]))
          }.should raise_error(ArgumentError, '+options[:order]+ entry "unknown" does not map to a property')
        end
      end

      describe 'that is an Array containing an invalid object' do
        it 'should raise an exception' do
          lambda {
            DataMapper::Query.new(@repository, @model, @options.update(:order => [ 1 ]))
          }.should raise_error(ArgumentError, '+options[:order]+ entry 1 of an unsupported object Fixnum')
        end
      end
    end

    describe 'with a unique option' do
      describe 'that is valid' do
        before do
          @return = @query = DataMapper::Query.new(@repository, @model, @options.freeze)
        end

        it 'should return a Query' do
          @return.should be_kind_of(DataMapper::Query)
        end

        it 'should set the unique? flag' do
          @query.unique?.should == @unique
        end
      end

      describe 'that is missing' do
        before do
          @return = @query = DataMapper::Query.new(@repository, @model, @options.except(:unique).freeze)
        end

        it 'should return a Query' do
          @return.should be_kind_of(DataMapper::Query)
        end

        it 'should set the query to not be unique' do
          @query.should_not be_unique
        end
      end

      describe 'that is invalid' do
        it 'should raise an exception' do
          lambda {
            DataMapper::Query.new(@repository, @model, @options.update(:unique => nil))
          }.should raise_error(ArgumentError, '+options[:unique]+ should be true or false, but was nil')
        end
      end
    end

    describe 'with an add_reversed option' do
      describe 'that is valid' do
        before do
          @return = @query = DataMapper::Query.new(@repository, @model, @options.freeze)
        end

        it 'should return a Query' do
          @return.should be_kind_of(DataMapper::Query)
        end

        it 'should set the add_reversed? flag' do
          @query.add_reversed?.should == @add_reversed
        end
      end

      describe 'that is missing' do
        before do
          @return = @query = DataMapper::Query.new(@repository, @model, @options.except(:add_reversed).freeze)
        end

        it 'should return a Query' do
          @return.should be_kind_of(DataMapper::Query)
        end

        it 'should set the query to not add in reverse order' do
          # TODO: think about renaming the flag to not sound 'clumsy'
          @query.should_not be_add_reversed
        end
      end

      describe 'that is invalid' do
        it 'should raise an exception' do
          lambda {
            DataMapper::Query.new(@repository, @model, @options.update(:add_reversed => nil))
          }.should raise_error(ArgumentError, '+options[:add_reversed]+ should be true or false, but was nil')
        end
      end
    end

    describe 'with a reload option' do
      describe 'that is valid' do
        before do
          @return = @query = DataMapper::Query.new(@repository, @model, @options.freeze)
        end

        it 'should return a Query' do
          @return.should be_kind_of(DataMapper::Query)
        end

        it 'should set the reload? flag' do
          @query.reload?.should == @reload
        end
      end

      describe 'that is missing' do
        before do
          @return = @query = DataMapper::Query.new(@repository, @model, @options.except(:reload).freeze)
        end

        it 'should return a Query' do
          @return.should be_kind_of(DataMapper::Query)
        end

        it 'should set the query to not reload' do
          @query.should_not be_reload
        end
      end

      describe 'that is invalid' do
        it 'should raise an exception' do
          lambda {
            DataMapper::Query.new(@repository, @model, @options.update(:reload => nil))
          }.should raise_error(ArgumentError, '+options[:reload]+ should be true or false, but was nil')
        end
      end
    end

    describe 'with options' do
      describe 'that are unknown' do
        before do
          @options.update(@options.delete(:conditions))

          @return = @query = DataMapper::Query.new(@repository, @model, @options.freeze)
        end

        it 'should return a Query' do
          @return.should be_kind_of(DataMapper::Query)
        end

        it 'should set the conditions' do
          @query.conditions.should == [ [ :eql, @model.properties[:name], @conditions[:name] ] ]
        end
      end

      describe 'that are invalid' do
        it 'should raise an exception' do
          lambda {
            DataMapper::Query.new(@repository, @model, 'invalid')
          }.should raise_error(ArgumentError, '+options+ should be Hash, but was String')
        end
      end
    end

    describe 'with no options' do
      before do
        @return = @query = DataMapper::Query.new(@repository, @model)
      end

      it 'should return a Query' do
        @return.should be_kind_of(DataMapper::Query)
      end

      it 'should set options to an empty Hash' do
        @query.options.should == {}
      end
    end
  end
end

# instance methods
describe DataMapper::Query do
  before do
    class ::User
      include DataMapper::Resource

      property :name, String, :key => true

      belongs_to :referrer, :model => self
    end

    @repository = DataMapper::Repository.new(:default)
    @model      = User
    @options    = {}
    @query      = DataMapper::Query.new(@repository, @model, @options)
    @original   = @query
  end

  it { @query.should respond_to(:==) }

  describe '#==' do
    describe 'when other is equal' do
      before do
        @return = @query == @query
      end

      it 'should return true' do
        @return.should be_true
      end
    end

    describe 'when other is equivalent' do
      before do
        @return = @query == @query.dup
      end

      it 'should return true' do
        @return.should be_true
      end
    end

    # TODO: iterate through all the Query attributes, and make one
    # different, and then check to make sure they are not equivalent
    describe 'when other is not an equivalent object' do
      before do
        @return = @query == @query.merge(:reload => true)
      end

      it 'should return false' do
        @return.should be_false
      end
    end

    describe 'when other is a different type of object that can be compared, and is equivalent' do
      it 'should return true'
    end

    describe 'when other is a different type of object that can be compared, and is not equivalent' do
      it 'should return false'
    end

    describe 'when other is a different type of object that cannot be compared' do
      before do
        @return = @query == 'invalid'
      end

      it 'should return false' do
        @return.should be_false
      end
    end
  end

  it { @query.should respond_to(:conditions) }

  describe '#conditions' do
    it 'should be awesome'
  end

  it { @query.should respond_to(:dup) }

  describe '#dup' do
    it 'should be awesome'
  end

  it { @query.should respond_to(:eql?) }

  describe '#eql?' do
    it 'should be awesome'
  end

  it { @query.should respond_to(:fields) }

  describe '#fields' do
    it 'should be awesome'
  end

  it { @query.should respond_to(:inspect) }

  describe '#inspect' do
    it 'should be awesome'
  end

  it { @query.should respond_to(:limit) }

  describe '#limit' do
    it 'should be awesome'
  end

  it { @query.should respond_to(:links) }

  describe '#links' do
    it 'should be awesome'
  end

  it { @query.should respond_to(:merge) }

  describe '#merge' do
    it 'should be awesome'
  end

  it { @query.should respond_to(:model) }

  describe '#model' do
    it 'should be awesome'
  end

  it { @query.should respond_to(:offset) }

  describe '#offset' do
    it 'should be awesome'
  end

  it { @query.should respond_to(:order) }

  describe '#order' do
    it 'should be awesome'
  end

  it { @query.should respond_to(:relative) }

  describe '#relative' do
    it 'should be awesome'
  end

  it { @query.should respond_to(:reload?) }

  describe '#reload?' do
    it 'should be awesome'
  end

  it { @query.should respond_to(:repository) }

  describe '#repository' do
    it 'should be awesome'
  end

  it { @query.should respond_to(:reverse) }

  describe '#reverse' do
    before do
      @return = @query = @query.reverse
    end

    it 'should return a Query' do
      @return.should be_kind_of(DataMapper::Query)
    end

    it 'should copy the Query' do
      @query.should_not be_equal(@original)
    end

    # TODO: push this into dup spec
    it 'should not reference original order' do
      @query.order.should_not be_equal(@original.order)
    end

    it 'should have a reversed order' do
      @query.order.should == [ DataMapper::Query::Direction.new(@model.properties[:name], :desc) ]
    end

    it 'should be equivalent, except for order' do
      @query.to_hash.except(:order).should == @original.to_hash.except(:order)
    end
  end

  it { @query.should respond_to(:reverse!) }

  describe '#reverse!' do
    before do
      @return = @query = @query.reverse!
    end

    it 'should return a Query' do
      @return.should be_kind_of(DataMapper::Query)
    end

    it 'should return self' do
      @query.should be_equal(@original)
    end

    it 'should have a reversed order' do
      @query.order.should == [ DataMapper::Query::Direction.new(@model.properties[:name], :desc) ]
    end
  end

  [ :slice, :[] ].each do |method|
    it { @query.should respond_to(method) }

    describe "##{method}" do
      it 'should be awesome'
    end
  end

  it { @query.should respond_to(:to_hash) }

  describe '#to_hash' do
    it 'should be awesome'
  end

  it { @query.should respond_to(:unique?) }

  describe '#unique?' do
    it 'should be awesome'
  end

  it { @query.should respond_to(:update) }

  describe '#update' do
    before do
      @other_options = {
        :fields       => [ @model.properties[:name] ].freeze,
        :links        => [ @model.relationships[:referrer] ].freeze,
        :conditions   => { :name => 'Dan Kubb' }.freeze,
        :offset       => 1,
        :limit        => 2,
        :order        => [ DataMapper::Query::Direction.new(@model.properties[:name], :desc) ].freeze,
        :unique       => true,
        :add_reversed => true,
        :reload       => true,
      }
    end

    describe 'with a Query' do
      describe 'that is equivalent' do
        before do
          @other = DataMapper::Query.new(@repository, @model)

          @return = @query = @query.update(@other)
        end

        it 'should return a Query' do
          @return.should be_kind_of(DataMapper::Query)
        end

        it 'should return self' do
          @query.should be_equal(@original)
        end
      end

      describe 'using a different repository' do
        it 'should raise an exception' do
          lambda {
            @query.update(DataMapper::Query.new(DataMapper::Repository.new(:other), User))
          }.should raise_error(ArgumentError, '+other+ DataMapper::Query must be for the default repository, not other')
        end
      end

      describe 'using a different model' do
        before do
          class ::Clone
            include DataMapper::Resource

            property :name, String, :key => true
          end
        end

        it 'should raise an exception' do
          lambda {
            @query.update(DataMapper::Query.new(@repository, Clone))
          }.should raise_error(ArgumentError, '+other+ DataMapper::Query must be for the User model, not Clone')
        end
      end

      describe 'using different options' do
        before do
          @other = DataMapper::Query.new(@repository, @model, @options.update(@other_options))

          @return = @query = @query.update(@other)
        end

        it 'should return a Query' do
          @return.should be_kind_of(DataMapper::Query)
        end

        it 'should return self' do
          @query.should be_equal(@original)
        end

        it 'should update the fields' do
          @query.fields.should == @options[:fields]
        end

        it 'should update the links' do
          @query.links.should == @options[:links]
        end

        it 'should update the conditions' do
          @query.conditions.should == [ [ :eql, @model.properties[:name], 'Dan Kubb' ] ]
        end

        it 'should update the offset' do
          @query.offset.should == @options[:offset]
        end

        it 'should update the limit' do
          @query.limit.should == @options[:limit]
        end

        it 'should update the order' do
          @query.order.should == @options[:order]
        end

        it 'should update the unique' do
          @query.unique?.should == @options[:unique]
        end

        it 'should update the add_reversed' do
          @query.add_reversed?.should == @options[:add_reversed]
        end

        it 'should update the reload' do
          @query.reload?.should == @options[:reload]
        end
      end

      describe 'using extra options' do
        before do
          @options.update(:name => 'Dan Kubb')
          @other = DataMapper::Query.new(@repository, @model, @options)

          @return = @query = @query.update(@other)
        end

        it 'should return a Query' do
          @return.should be_kind_of(DataMapper::Query)
        end

        it 'should return self' do
          @query.should be_equal(@original)
        end

        it 'should update the conditions' do
          @query.conditions.should == [ [ :eql, @model.properties[:name], @options[:name] ] ]
        end
      end
    end

    describe 'with a Hash' do
      describe 'that is empty' do
        before do
          @copy = @query.dup
          @return = @query = @query.update({})
        end

        it 'should return a Query' do
          @return.should be_kind_of(DataMapper::Query)
        end

        it 'should return self' do
          @query.should be_equal(@original)
        end

        it 'should not change the Query' do
          @query.should == @copy
        end
      end

      describe 'using different options' do
        before do
          @return = @query = @query.update(@other_options)
        end

        it 'should return a Query' do
          @return.should be_kind_of(DataMapper::Query)
        end

        it 'should return self' do
          @query.should be_equal(@original)
        end

        it 'should update the fields' do
          @query.fields.should == @other_options[:fields]
        end

        it 'should update the links' do
          @query.links.should == @other_options[:links]
        end

        it 'should update the conditions' do
          @query.conditions.should == [ [ :eql, @model.properties[:name], 'Dan Kubb' ] ]
        end

        it 'should update the offset' do
          @query.offset.should == @other_options[:offset]
        end

        it 'should update the limit' do
          @query.limit.should == @other_options[:limit]
        end

        it 'should update the order' do
          @query.order.should == @other_options[:order]
        end

        it 'should update the unique' do
          @query.unique?.should == @other_options[:unique]
        end

        it 'should update the add_reversed' do
          @query.add_reversed?.should == @other_options[:add_reversed]
        end

        it 'should update the reload' do
          @query.reload?.should == @other_options[:reload]
        end
      end

      describe 'using extra options' do
        before do
          @options = { :name => 'Dan Kubb' }

          @return = @query = @query.update(@options)
        end

        it 'should return a Query' do
          @return.should be_kind_of(DataMapper::Query)
        end

        it 'should return self' do
          @query.should be_equal(@original)
        end

        it 'should update the conditions' do
          @query.conditions.should == [ [ :eql, @model.properties[:name], @options[:name] ] ]
        end
      end
    end
  end
end
