require 'pathname'
require Pathname(__FILE__).dirname.expand_path + 'spec_helper'

describe DataMapper::Query do
  GOOD_OPTIONS = [
    [ :reload,  false     ],
    [ :reload,  true      ],
    [ :offset,  0         ],
    [ :offset,  1         ],
    [ :limit,   1         ],
    [ :limit,   2         ],
    [ :order,   [ :stub ] ], # TODO: fill in allowed default value
    [ :fields,  [ :stub ] ], # TODO: fill in allowed default value
    [ :link,    [ :stub ] ], # TODO: fill in allowed default value
    [ :include, [ :stub ] ], # TODO: fill in allowed default value
  ]

  BAD_OPTIONS = {
    :reload     => 'true',
    :offset     => -1,
    :limit      => 0,
    :order      => [],
    :fields     => [],
    :link       => [],
    :include    => [],
    :conditions => [],
  }

  # flatten GOOD_OPTIONS into a Hash to remove default values, since
  # default value, when defined, is always listed first in GOOD_OPTIONS
  UPDATED_OPTIONS = GOOD_OPTIONS.inject({}) do |options,(attribute,value)|
    options.update attribute => value
  end

  before :all do
    class Article
      include DataMapper::Resource
    end

    class Comment
      include DataMapper::Resource
    end

    class NormalClass
      # should not include DataMapper::Resource
    end
  end

  describe '.new' do
    describe 'should set the attribute' do
      it '#resource with resource' do
        query = DataMapper::Query.new(Article)
        query.resource.should == Article
      end

      GOOD_OPTIONS.each do |(attribute,value)|
        it "##{attribute} with options[:#{attribute}] if it is #{value.inspect}" do
          query = DataMapper::Query.new(Article, attribute => value)
          query.send(attribute).should == value
        end
      end

      describe ' #conditions with options[:conditions]' do
        it 'when they have a one element Array' do
          query = DataMapper::Query.new(Article, :conditions => [ 'name = "dkubb"' ])
          query.conditions.should == [ [ 'name = "dkubb"' ] ]
        end

        it 'when they have a two or more element Array' do
          query = DataMapper::Query.new(Article, :conditions => [ 'name = ?', 'dkubb' ])
          query.conditions.should == [ [ 'name = ?', [ 'dkubb' ] ] ]
        end
      end

      describe ' #conditions with unknown options' do
        it 'when a Symbol object is a key' do
          query = DataMapper::Query.new(Article, :author => 'dkubb')
          query.conditions.should == [ [ :eql, :author, 'dkubb' ] ]
        end

        it 'when a Symbol::Operator object is a key' do
          query = DataMapper::Query.new(Article, :author.like => /\Ad(?:an\.)kubb\z/)
          query.conditions.should == [ [ :like, :author, /\Ad(?:an\.)kubb\z/ ] ]
        end
      end
    end

    describe 'should raise an ArgumentError' do
      it 'when resource is nil' do
        lambda {
          DataMapper::Query.new(nil)
        }.should raise_error(ArgumentError)
      end

      it 'when resource is a Class that does not include DataMapper::Resource' do
        lambda {
          DataMapper::Query.new(NormalClass)
        }.should raise_error(ArgumentError)
      end

      it 'when options is not a Hash' do
        lambda {
          DataMapper::Query.new(Article, nil)
        }.should raise_error(ArgumentError)
      end

      BAD_OPTIONS.each do |attribute,value|
        it "when options[:#{attribute}] is nil" do
          lambda {
            DataMapper::Query.new(Article, attribute => nil)
          }.should raise_error(ArgumentError)
        end

        it "when options[:#{attribute}] is #{value.kind_of?(Array) && value.empty? ? 'an empty Array' : value.inspect}" do
          lambda {
            DataMapper::Query.new(Article, attribute => value)
          }.should raise_error(ArgumentError)
        end
      end

      it 'when unknown options use something that is not a Symbol::Operator, Symbol or String is a key' do
        lambda {
          DataMapper::Query.new(Article, nil => nil)
        }.should raise_error(ArgumentError)
      end
    end
  end

  describe '#update' do
    before do
      @query = DataMapper::Query.new(Article, UPDATED_OPTIONS)
    end

    it 'should instantiate a DataMapper::Query object from other when it is a Hash' do
      other = { :reload => :true }

      mock_query_class = mock('DataMapper::Query class')
      @query.should_receive(:class).with(no_args).ordered.and_return(mock_query_class)
      mock_query_class.should_receive(:new).with(@query.resource, other).ordered.and_return(@query)

      @query.update(other)
    end

    it 'should return self' do
      other = DataMapper::Query.new(Article)
      @query.update(other).should == @query
    end

    describe 'should overwrite the attribute' do
      it '#resource with other resource' do
        other = DataMapper::Query.new(Comment)
        @query.update(other).resource.should == Comment
      end

      it '#reload with other reload' do
        other = DataMapper::Query.new(Comment, :reload => true)
        @query.update(other).reload.should == true
      end

      it '#offset with other offset when it is not equal to 0' do
        other = DataMapper::Query.new(Comment, :offset => 1)
        @query.update(other).offset.should == 1
      end

      it '#limit with other limit when it is not nil' do
        other = DataMapper::Query.new(Comment, :limit => 1)
        @query.update(other).limit.should == 1
      end

      [ :eql, :like ].each do |operator|
        it "#conditions with other conditions when updating the '#{operator}' clause to a different value than in self" do
          # set the initial conditions
          @query.update(:author.send(operator) => 'ssmoot')

          # update the conditions, and overwrite with the new value
          other = DataMapper::Query.new(Comment, :author.send(operator) => 'dkubb')
          @query.update(other).conditions.should == [ [ operator, :author, 'dkubb' ] ]
        end
      end

      [ :gt, :gte ].each do |operator|
        it "#conditions with other conditions when updating the '#{operator}' clause to a value less than in self" do
          # set the initial conditions
          @query.update(:created_at.send(operator) => Time.at(1))

          # update the conditions, and overwrite with the new value is less
          other = DataMapper::Query.new(Comment, :created_at.send(operator) => Time.at(0))
          @query.update(other).conditions.should == [ [ operator, :created_at, Time.at(0) ] ]
        end
      end

      [ :lt, :lte ].each do |operator|
        it "#conditions with other conditions when updating the '#{operator}' clause to a value greater than in self" do
          # set the initial conditions
          @query.update(:created_at.send(operator) => Time.at(0))

          # update the conditions, and overwrite with the new value is more
          other = DataMapper::Query.new(Comment, :created_at.send(operator) => Time.at(1))
          @query.update(other).conditions.should == [ [ operator, :created_at, Time.at(1) ] ]
        end
      end
    end

    describe 'should append the attribute' do
      [ :order, :fields, :link, :include ].each do |attribute|
        it "##{attribute} with other #{attribute} unique values" do
          other = DataMapper::Query.new(Comment, attribute => [ :other, :stub, :new ])
          @query.update(other).send(attribute).should == [ :stub, :other, :new ]
        end
      end

      it '#conditions with other conditions when they are unique' do
        # set the initial conditions
        @query.update(:title => 'On DataMapper')

        # update the conditions, but merge the conditions together
        other = DataMapper::Query.new(Comment, :author => 'dkubb')
        @query.update(other).conditions.should == [ [ :eql, :title, 'On DataMapper' ], [ :eql, :author, 'dkubb' ] ]
      end

      [ :not, :in ].each do |operator|
        it "#conditions with other conditions when updating the '#{operator}' clause" do
          # set the initial conditions
          @query.update(:created_at.send(operator) => [ Time.at(0) ])

          # update the conditions, and overwrite with the new value is more
          other = DataMapper::Query.new(Comment, :created_at.send(operator) => [ Time.at(1) ])
          @query.update(other).conditions.should == [ [ operator, :created_at, [ Time.at(0), Time.at(1) ] ] ]
        end
      end

      it '#conditions with other conditions when they have a one element condition' do
        # set the initial conditions
        @query.update(:title => 'On DataMapper')

        # update the conditions, but merge the conditions together
        other = DataMapper::Query.new(Comment, :conditions => [ 'author = "dkubb"' ])
        @query.update(other).conditions.should == [ [ :eql, :title, 'On DataMapper' ], [ 'author = "dkubb"' ] ]
      end

      it '#conditions with other conditions when they have a two or more element condition' do
        # set the initial conditions
        @query.update(:title => 'On DataMapper')

        # update the conditions, but merge the conditions together
        other = DataMapper::Query.new(Comment, :conditions => [ 'author = ?', 'dkubb' ])
        @query.update(other).conditions.should == [ [ :eql, :title, 'On DataMapper' ], [ 'author = ?', [ 'dkubb' ] ] ]
      end
    end

    describe 'should not update the attribute' do
      it '#offset when other offset is equal to 0' do
        other = DataMapper::Query.new(Comment, :offset => 0)
        other.offset.should == 0
        @query.update(other).offset.should == 1
      end

      it '#limit when other limit is nil' do
        other = DataMapper::Query.new(Comment)
        other.limit.should be_nil
        @query.update(other).offset.should == 1
      end

      [ :gt, :gte ].each do |operator|
        it "#conditions with other conditions when they have a '#{operator}' clause with a value greater than in self" do
          # set the initial conditions
          @query.update(:created_at.send(operator) => Time.at(0))

          # do not overwrite with the new value if it is more
          other = DataMapper::Query.new(Comment, :created_at.send(operator) => Time.at(1))
          @query.update(other).conditions.should == [ [ operator, :created_at, Time.at(0) ] ]
        end
      end

      [ :lt, :lte ].each do |operator|
        it "#conditions with other conditions when they have a '#{operator}' clause with a value less than in self" do
          # set the initial conditions
          @query.update(:created_at.send(operator) => Time.at(1))

          # do not overwrite with the new value if it is less
          other = DataMapper::Query.new(Comment, :created_at.send(operator) => Time.at(0))
          @query.update(other).conditions.should == [ [ operator, :created_at, Time.at(1) ] ]
        end
      end
    end
  end

  describe '#merge' do
    before do
      @query = DataMapper::Query.new(Article)
    end

    it 'should pass arguments as-is to duplicate object\'s #update method' do
      dupe_query = @query.dup
      @query.should_receive(:dup).with(no_args).ordered.and_return(dupe_query)
      dupe_query.should_receive(:update).with(:author => 'dkubb').ordered
      @query.merge(:author => 'dkubb')
    end

    it 'should return the duplicate object' do
      dupe_query = @query.merge(:author => 'dkubb')
      @query.object_id.should_not == dupe_query.object_id
      @query.merge(:author => 'dkubb').should == dupe_query
    end
  end

  describe '#==' do
    before do
      @query = DataMapper::Query.new(Article)
    end

    describe 'should be equal' do
      it 'when other is same object' do
        @query.update(:author => 'dkubb').should == @query
      end

      it 'when other has the same attributes' do
        other = DataMapper::Query.new(Article)
        @query.object_id.should_not == other.object_id
        @query.should == other
      end

      it 'when other has the same conditions sorted differently' do
        @query.update(:author => 'dkubb')
        @query.update(:title  => 'On DataMapper')

        other = DataMapper::Query.new(Article, :title => 'On DataMapper')
        other.update(:author => 'dkubb')

        # query conditions are in different order
        @query.conditions.should == [ [ :eql, :author, 'dkubb' ],        [ :eql, :title, 'On DataMapper' ] ]
        other.conditions.should  == [ [ :eql, :title, 'On DataMapper' ], [ :eql, :author, 'dkubb' ]        ]

        @query.should == other
      end
    end

    describe 'should be different' do
      it 'when other resource is different than self.resource' do
        @query.should_not == DataMapper::Query.new(Comment)
      end

      UPDATED_OPTIONS.each do |attribute,value|
        it "when other #{attribute} is different than self.#{attribute}" do
          @query.should_not == DataMapper::Query.new(Article, attribute => value)
        end
      end

      it 'when other conditions are different than self.conditions' do
        @query.should_not == DataMapper::Query.new(Article, :author => 'dkubb')
      end
    end
  end
end
