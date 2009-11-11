require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

require 'ostruct'

# TODO: make some of specs for Query.new shared.  the assertions and
# normalizations should happen for Query#update, Query#relative and
# Query#merge and should probably be in shared specs

# class methods
describe DataMapper::Query do
  before :all do
    class ::Password < DataMapper::Type
      primitive String
      length    40
    end

    class ::User
      include DataMapper::Resource

      property :name,     String,   :key => true
      property :password, Password
      property :balance,  BigDecimal

      belongs_to :referrer, self, :required => false
      has n, :referrals, self, :inverse => :referrer
    end

    @repository = DataMapper::Repository.new(:default)
    @model      = User

    @fields       = [ :name ].freeze
    @links        = [ :referrer ].freeze
    @conditions   = { :name => 'Dan Kubb' }
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

  it { DataMapper::Query.should respond_to(:new) }

  describe '.new' do
    describe 'with a repository' do
      describe 'that is valid' do
        before :all do
          @return = DataMapper::Query.new(@repository, @model, @options.freeze)
        end

        it { @return.should be_kind_of(DataMapper::Query) }

        it 'should set the repository' do
          @return.repository.should == @repository
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
        before :all do
          @return = DataMapper::Query.new(@repository, @model, @options.freeze)
        end

        it { @return.should be_kind_of(DataMapper::Query) }

        it 'should set the model' do
          @return.model.should == @model
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
        before :all do
          @return = DataMapper::Query.new(@repository, @model, @options.freeze)
        end

        it { @return.should be_kind_of(DataMapper::Query) }

        it 'should set the fields' do
          @return.fields.should == @model.properties.values_at(*@fields)
        end
      end

      describe 'that is an Array containing a String' do
        before :all do
          @options[:fields] = [ 'name' ]

          @return = DataMapper::Query.new(@repository, @model, @options.freeze)
        end

        it { @return.should be_kind_of(DataMapper::Query) }

        it 'should set the fields' do
          @return.fields.should == @model.properties.values_at('name')
        end
      end

      describe 'that is an Array containing a Property' do
        before :all do
          @options[:fields] = @model.properties.values_at(:name)

          @return = DataMapper::Query.new(@repository, @model, @options.freeze)
        end

        it { @return.should be_kind_of(DataMapper::Query) }

        it 'should set the fields' do
          @return.fields.should == @model.properties.values_at(:name)
        end
      end

      describe 'that is an Array containing a Property from an ancestor' do
        before :all do
          class ::Contact < User; end

          @options[:fields] = User.properties.values_at(:name)

          @return = DataMapper::Query.new(@repository, Contact, @options.freeze)
        end

        it { @return.should be_kind_of(DataMapper::Query) }

        it 'should set the fields' do
          @return.fields.should == User.properties.values_at(:name)
        end
      end

      describe 'that is missing' do
        before :all do
          @return = DataMapper::Query.new(@repository, @model, @options.except(:fields).freeze)
        end

        it { @return.should be_kind_of(DataMapper::Query) }

        it 'should set fields to the model default properties' do
          @return.fields.should == @model.properties.defaults
        end
      end

      describe 'that is invalid' do
        it 'should raise an exception' do
          lambda {
            DataMapper::Query.new(@repository, @model, @options.update(:fields => :name))
          }.should raise_error(ArgumentError, '+options[:fields]+ should be Array, but was Symbol')
        end
      end

      describe 'that is an Array containing an unknown Symbol' do
        it 'should raise an exception' do
          lambda {
            DataMapper::Query.new(@repository, @model, @options.update(:fields => [ :unknown ]))
          }.should raise_error(ArgumentError, "+options[:fields]+ entry :unknown does not map to a property in #{@model}")
        end
      end

      describe 'that is an Array containing an unknown String' do
        it 'should raise an exception' do
          lambda {
            DataMapper::Query.new(@repository, @model, @options.update(:fields => [ 'unknown' ]))
          }.should raise_error(ArgumentError, "+options[:fields]+ entry \"unknown\" does not map to a property in #{@model}")
        end
      end

      describe 'that is an Array containing an invalid object' do
        it 'should raise an exception' do
          lambda {
            DataMapper::Query.new(@repository, @model, @options.update(:fields => [ 1 ]))
          }.should raise_error(ArgumentError, '+options[:fields]+ entry 1 of an unsupported object Fixnum')
        end
      end

      describe 'that is an Array containing an unknown Property' do
        it 'should raise an exception' do
          lambda {
            DataMapper::Query.new(@repository, @model, @options.update(:fields => [ DataMapper::Property.new(@model, :unknown, String) ]))
          }.should raise_error(ArgumentError, "+options[:field]+ entry :unknown does not map to a property in #{@model}")
        end
      end
    end

    describe 'with a links option' do
      describe 'that is an Array containing a Symbol' do
        before :all do
          @return = DataMapper::Query.new(@repository, @model, @options.freeze)
        end

        it { @return.should be_kind_of(DataMapper::Query) }

        it 'should set the links' do
          @return.links.should == @model.relationships.values_at(*@links)
        end
      end

      describe 'that is an Array containing a String' do
        before :all do
          @options[:links] = [ 'referrer' ]

          @return = DataMapper::Query.new(@repository, @model, @options.freeze)
        end

        it { @return.should be_kind_of(DataMapper::Query) }

        it 'should set the links' do
          @return.links.should == @model.relationships.values_at('referrer')
        end
      end

      describe 'that is an Array containing a Relationship' do
        before :all do
          @options[:links] = @model.relationships.values_at(:referrer)

          @return = DataMapper::Query.new(@repository, @model, @options.freeze)
        end

        it { @return.should be_kind_of(DataMapper::Query) }

        it 'should set the links' do
          @return.links.should == @model.relationships.values_at(:referrer)
        end
      end

      describe 'that is missing' do
        before :all do
          @return = DataMapper::Query.new(@repository, @model, @options.except(:links).freeze)
        end

        it { @return.should be_kind_of(DataMapper::Query) }

        it 'should set links to an empty Array' do
          @return.links.should == []
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
          }.should raise_error(ArgumentError, "+options[:links]+ entry :unknown does not map to a relationship in #{@model}")
        end
      end

      describe 'that is an Array containing an unknown String' do
        it 'should raise an exception' do
          lambda {
            DataMapper::Query.new(@repository, @model, @options.update(:links => [ 'unknown' ]))
          }.should raise_error(ArgumentError, "+options[:links]+ entry \"unknown\" does not map to a relationship in #{@model}")
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
        describe 'with the Property key' do
          before :all do
            @options[:conditions] = { @model.properties[:name] => 'Dan Kubb' }
            @return = DataMapper::Query.new(@repository, @model, @options.freeze)
          end

          it { @return.should be_kind_of(DataMapper::Query) }

          it 'should set the conditions' do
            @return.conditions.should ==
              DataMapper::Query::Conditions::Operation.new(
                :and,
                DataMapper::Query::Conditions::Comparison.new(
                  :eql,
                  @model.properties[:name],
                  'Dan Kubb'
                )
              )
          end

          it 'should be valid' do
            @return.should be_valid
          end
        end

        describe 'with the Symbol key mapping to a Property' do
          before :all do
            @return = DataMapper::Query.new(@repository, @model, @options.freeze)
          end

          it { @return.should be_kind_of(DataMapper::Query) }

          it 'should set the conditions' do
            @return.conditions.should ==
              DataMapper::Query::Conditions::Operation.new(
                :and,
                DataMapper::Query::Conditions::Comparison.new(
                  :eql,
                  @model.properties[:name],
                  'Dan Kubb'
                )
              )
          end

          it 'should be valid' do
            @return.should be_valid
          end
        end

        describe 'with the String key mapping to a Property' do
          before :all do
            @options[:conditions] = { 'name' => 'Dan Kubb' }
            @return = DataMapper::Query.new(@repository, @model, @options.freeze)
          end

          it { @return.should be_kind_of(DataMapper::Query) }

          it 'should set the conditions' do
            @return.conditions.should ==
              DataMapper::Query::Conditions::Operation.new(
                :and,
                DataMapper::Query::Conditions::Comparison.new(
                  :eql,
                  @model.properties[:name],
                  'Dan Kubb'
                )
              )
          end

          it 'should be valid' do
            @return.should be_valid
          end
        end

        supported_by :all do
          describe 'with the Symbol key mapping to a Relationship' do
            before :all do
              @user = @model.create(:name => 'Dan Kubb')

              @options[:conditions] = { :referrer => @user }

              @return = DataMapper::Query.new(@repository, @model, @options.freeze)
            end

            it { @return.should be_kind_of(DataMapper::Query) }

            it 'should set the conditions' do
              @return.conditions.should ==
                DataMapper::Query::Conditions::Operation.new(
                  :and,
                  DataMapper::Query::Conditions::Comparison.new(
                    :eql,
                    @model.relationships[:referrer],
                    @user
                  )
                )
            end

            it 'should be valid' do
              @return.should be_valid
            end
          end

          describe 'with the String key mapping to a Relationship' do
            before :all do
              @user = @model.create(:name => 'Dan Kubb')

              @options[:conditions] = { 'referrer' => @user }

              @return = DataMapper::Query.new(@repository, @model, @options.freeze)
            end

            it { @return.should be_kind_of(DataMapper::Query) }

            it 'should set the conditions' do
              @return.conditions.should ==
                DataMapper::Query::Conditions::Operation.new(
                  :and,
                  DataMapper::Query::Conditions::Comparison.new(
                    :eql,
                    @model.relationships['referrer'],
                    @user
                  )
                )
            end

            it 'should be valid' do
              @return.should be_valid
            end
          end

          describe 'with the Symbol key mapping to a Relationship and a nil value' do
            before :all do
              @options[:conditions] = { :referrer => nil }

              @return = DataMapper::Query.new(@repository, @model, @options.freeze)
            end

            it { @return.should be_kind_of(DataMapper::Query) }

            it 'should set the conditions' do
              @return.conditions.should ==
                DataMapper::Query::Conditions::Operation.new(
                  :and,
                  DataMapper::Query::Conditions::Comparison.new(
                    :eql,
                    @model.relationships[:referrer],
                    nil
                  )
                )
            end

            it 'should be valid' do
              @return.should be_valid
            end
          end

          describe 'with the Symbol key mapping to a Relationship and an empty Array' do
            before :all do
              @options[:conditions] = { :referrer => [] }

              @return = DataMapper::Query.new(@repository, @model, @options.freeze)
            end

            it { @return.should be_kind_of(DataMapper::Query) }

            it 'should set the conditions' do
              @return.conditions.should ==
                DataMapper::Query::Conditions::Operation.new(
                  :and,
                  DataMapper::Query::Conditions::Comparison.new(
                    :in,
                    @model.relationships[:referrer],
                    []
                  )
                )
            end

            it 'should be invalid' do
              @return.should_not be_valid
            end
          end
        end

        describe 'with the Query::Operator key' do
          before :all do
            @options[:conditions] = { :name.gte => 'Dan Kubb' }
            @return = DataMapper::Query.new(@repository, @model, @options.freeze)
          end

          it { @return.should be_kind_of(DataMapper::Query) }

          it 'should set the conditions' do
            @return.conditions.should ==
              DataMapper::Query::Conditions::Operation.new(
                :and,
                DataMapper::Query::Conditions::Comparison.new(
                  :gte,
                  @model.properties[:name],
                  'Dan Kubb'
                )
              )
          end

          it 'should be valid' do
            @return.should be_valid
          end
        end

        describe 'with the Query::Path key' do
          before :all do
            @options[:conditions] = { @model.referrer.name => 'Dan Kubb' }
            @return = DataMapper::Query.new(@repository, @model, @options.freeze)
          end

          it { @return.should be_kind_of(DataMapper::Query) }

          it 'should set the conditions' do
            @return.conditions.should ==
              DataMapper::Query::Conditions::Operation.new(
                :and,
                DataMapper::Query::Conditions::Comparison.new(
                  :eql,
                  @model.referrer.name,
                  'Dan Kubb'
                )
              )
          end

          it 'should set the links' do
            @return.links.should == [ @model.relationships[:referrals], @model.relationships[:referrer] ]
          end

          it 'should be valid' do
            @return.should be_valid
          end
        end

        describe 'with the String key mapping to a Query::Path' do
          before :all do
            @options[:conditions] = { 'referrer.name' => 'Dan Kubb' }
            @return = DataMapper::Query.new(@repository, @model, @options.freeze)
          end

          it { @return.should be_kind_of(DataMapper::Query) }

          it 'should set the conditions' do
            @return.conditions.should ==
              DataMapper::Query::Conditions::Operation.new(
                :and,
                DataMapper::Query::Conditions::Comparison.new(
                  :eql,
                  @model.referrer.name,
                  'Dan Kubb'
                )
              )
          end

          it 'should set the links' do
            @return.links.should == [ @model.relationships[:referrals], @model.relationships[:referrer] ]
          end

          it 'should be valid' do
            @return.should be_valid
          end
        end

        describe 'with an Array with 1 entry' do
          before :all do
            @options[:conditions] = { :name => [ 'Dan Kubb' ] }
            @return = DataMapper::Query.new(@repository, @model, @options.freeze)
          end

          it { @return.should be_kind_of(DataMapper::Query) }

          it 'should set the conditions' do
            pending do
              @return.conditions.should ==
                DataMapper::Query::Conditions::Operation.new(
                  :and,
                  DataMapper::Query::Conditions::Comparison.new(
                    :eql,
                    @model.properties[:name],
                    'Dan Kubb'
                  )
                )
            end
          end

          it 'should be valid' do
            @return.should be_valid
          end
        end

        describe 'with an Array with no entries' do
          before :all do
            @options[:conditions] = { :name => [] }
            @return = DataMapper::Query.new(@repository, @model, @options.freeze)
          end

          it { @return.should be_kind_of(DataMapper::Query) }

          it 'should set the conditions' do
            pending do
              @return.conditions.should ==
                DataMapper::Query::Conditions::Operation.new(
                  :and,
                  DataMapper::Query::Conditions::Comparison.new(
                    :eql,
                    @model.properties[:name],
                    'Dan Kubb'
                  )
                )
            end
          end

          it 'should not be valid' do
            @return.should_not be_valid
          end
        end

        describe 'with an Array with duplicate entries' do
          before :all do
            @options[:conditions] = { :name => [ 'John Doe', 'Dan Kubb', 'John Doe' ] }
            @return = DataMapper::Query.new(@repository, @model, @options.freeze)
          end

          it { @return.should be_kind_of(DataMapper::Query) }

          it 'should set the conditions' do
            @return.conditions.should ==
              DataMapper::Query::Conditions::Operation.new(
                :and,
                DataMapper::Query::Conditions::Comparison.new(
                  :in,
                  @model.properties[:name],
                  [ 'John Doe', 'Dan Kubb' ]
                )
              )
          end

          it 'should be valid' do
            @return.should be_valid
          end
        end

        describe 'with a custom Property' do
          before :all do
            @options[:conditions] = { :password => 'password' }
            @return = DataMapper::Query.new(@repository, @model, @options.freeze)
          end

          it { @return.should be_kind_of(DataMapper::Query) }

          it 'should set the conditions' do
            @return.conditions.should ==
              DataMapper::Query::Conditions::Operation.new(
                :and,
                DataMapper::Query::Conditions::Comparison.new(
                  :eql,
                  @model.properties[:password],
                  'password'
                )
              )
          end

          it 'should be valid' do
            @return.should be_valid
          end
        end

        describe 'with a Symbol for a String property' do
          before :all do
            @options[:conditions] = { :name => 'Dan Kubb'.to_sym }
            @return = DataMapper::Query.new(@repository, @model, @options.freeze)
          end

          it { @return.should be_kind_of(DataMapper::Query) }

          it 'should set the conditions' do
            @return.conditions.should ==
              DataMapper::Query::Conditions::Operation.new(
                :and,
                DataMapper::Query::Conditions::Comparison.new(
                  :eql,
                  @model.properties[:name],
                  'Dan Kubb'  # typecast value
                )
              )
          end

          it 'should be valid' do
            @return.should be_valid
          end
        end

        describe 'with a Float for a BigDecimal property' do
          before :all do
            @options[:conditions] = { :balance => 50.5 }
            @return = DataMapper::Query.new(@repository, @model, @options.freeze)
          end

          it { @return.should be_kind_of(DataMapper::Query) }

          it 'should set the conditions' do
            @return.conditions.should ==
              DataMapper::Query::Conditions::Operation.new(
                :and,
                DataMapper::Query::Conditions::Comparison.new(
                  :eql,
                  @model.properties[:balance],
                  BigDecimal('50.5')  # typecast value
                )
              )
          end

          it 'should be valid' do
            @return.should be_valid
          end
        end
      end

      describe 'that is a valid Array' do
        before :all do
          @options[:conditions] = [ 'name = ?', 'Dan Kubb' ]

          @return = DataMapper::Query.new(@repository, @model, @options.freeze)
        end

        it { @return.should be_kind_of(DataMapper::Query) }

        it 'should set the conditions' do
          @return.conditions.should == DataMapper::Query::Conditions::Operation.new(:and, [ 'name = ?', [ 'Dan Kubb' ] ])
        end

        it 'should be valid' do
          @return.should be_valid
        end
      end

      describe 'that is missing' do
        before :all do
          @return = DataMapper::Query.new(@repository, @model, @options.except(:conditions).freeze)
        end

        it { @return.should be_kind_of(DataMapper::Query) }

        it 'should set conditions to nil by default' do
          @return.conditions.should be_nil
        end

        it 'should be valid' do
          @return.should be_valid
        end
      end

      describe 'that is invalid' do
        it 'should raise an exception' do
          lambda {
            DataMapper::Query.new(@repository, @model, @options.update(:conditions => 'invalid'))
          }.should raise_error(ArgumentError, '+options[:conditions]+ should be DataMapper::Query::Conditions::AbstractOperation or DataMapper::Query::Conditions::AbstractComparison or Hash or Array, but was String')
        end
      end

      describe 'that is an empty Array' do
        it 'should raise an exception' do
          lambda {
            DataMapper::Query.new(@repository, @model, @options.update(:conditions => []))
          }.should raise_error(ArgumentError, '+options[:conditions]+ should not be empty')
        end
      end

      describe 'that is an Array with a blank statement' do
        it 'should raise an exception' do
          lambda {
            DataMapper::Query.new(@repository, @model, @options.update(:conditions => [ ' ' ]))
          }.should raise_error(ArgumentError, '+options[:conditions]+ should have a statement for the first entry')
        end
      end

      describe 'that is a Hash with a Symbol key that is not for a Property in the model' do
        it 'should raise an exception' do
          lambda {
            DataMapper::Query.new(@repository, @model, @options.update(:conditions => { :unknown => 1 }))
          }.should raise_error(ArgumentError, "condition :unknown does not map to a property or relationship in #{@model}")
        end
      end

      describe 'that is a Hash with a String key that is not for a Property in the model' do
        it 'should raise an exception' do
          lambda {
            DataMapper::Query.new(@repository, @model, @options.update(:conditions => { 'unknown' => 1 }))
          }.should raise_error(ArgumentError, "condition \"unknown\" does not map to a property or relationship in #{@model}")
        end
      end

      describe 'that is a Hash with a Query::Operator key that is not for a Property in the model' do
        it 'should raise an exception' do
          lambda {
            DataMapper::Query.new(@repository, @model, @options.update(:conditions => { :unknown.asc => 1 }))
          }.should raise_error(ArgumentError, 'condition #<DataMapper::Query::Operator @target=:unknown @operator=:asc> used an invalid operator asc')
        end
      end

      describe 'that is a Hash with a key of a type that is not permitted' do
        it 'should raise an exception' do
          lambda {
            DataMapper::Query.new(@repository, @model, @options.update(:conditions => { 1 => 1 }))
          }.should raise_error(ArgumentError, 'condition 1 of an unsupported object Fixnum')
        end
      end
    end

    describe 'with an offset option' do
      describe 'that is valid' do
        before :all do
          @return = DataMapper::Query.new(@repository, @model, @options.freeze)
        end

        it { @return.should be_kind_of(DataMapper::Query) }

        it 'should set the offset' do
          @return.offset.should == @offset
        end
      end

      describe 'that is missing' do
        before :all do
          @return = DataMapper::Query.new(@repository, @model, @options.except(:offset).freeze)
        end

        it { @return.should be_kind_of(DataMapper::Query) }

        it 'should set offset to 0' do
          @return.offset.should == 0
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

      describe 'that is greater than 0 and a nil limit' do
        it 'should raise an exception' do
          lambda {
            DataMapper::Query.new(@repository, @model, @options.except(:limit).update(:offset => 1))
          }.should raise_error(ArgumentError, '+options[:offset]+ cannot be greater than 0 if limit is not specified')
        end
      end
    end

    describe 'with a limit option' do
      describe 'that is valid' do
        before :all do
          @return = DataMapper::Query.new(@repository, @model, @options.freeze)
        end

        it { @return.should be_kind_of(DataMapper::Query) }

        it 'should set the limit' do
          @return.limit.should == @limit
        end
      end

      describe 'that is missing' do
        before :all do
          @return = DataMapper::Query.new(@repository, @model, @options.except(:limit).freeze)
        end

        it { @return.should be_kind_of(DataMapper::Query) }

        it 'should set limit to nil' do
          @return.limit.should be_nil
        end
      end

      describe 'that is invalid' do
        it 'should raise an exception' do
          lambda {
            DataMapper::Query.new(@repository, @model, @options.update(:limit => '1'))
          }.should raise_error(ArgumentError, '+options[:limit]+ should be Integer, but was String')
        end
      end

      describe 'that is less than 0' do
        it 'should raise an exception' do
          lambda {
            DataMapper::Query.new(@repository, @model, @options.update(:limit => -1))
          }.should raise_error(ArgumentError, '+options[:limit]+ must be greater than or equal to 0, but was -1')
        end
      end
    end

    describe 'with an order option' do
      describe 'that is a single Symbol' do
        before :all do
          @options[:order] = :name
          @return = DataMapper::Query.new(@repository, @model, @options.freeze)
        end

        it { @return.should be_kind_of(DataMapper::Query) }

        it 'should set the order' do
          @return.order.should == [ DataMapper::Query::Direction.new(@model.properties[:name]) ]
        end
      end

      describe 'that is a single String' do
        before :all do
          @options[:order] = 'name'
          @return = DataMapper::Query.new(@repository, @model, @options.freeze)
        end

        it { @return.should be_kind_of(DataMapper::Query) }

        it 'should set the order' do
          @return.order.should == [ DataMapper::Query::Direction.new(@model.properties[:name]) ]
        end
      end

      describe 'that is a single Property' do
        before :all do
          @options[:order] = @model.properties.values_at(:name)
          @return = DataMapper::Query.new(@repository, @model, @options.freeze)
        end

        it { @return.should be_kind_of(DataMapper::Query) }

        it 'should set the order' do
          @return.order.should == [ DataMapper::Query::Direction.new(@model.properties[:name]) ]
        end
      end
      describe 'that is an Array containing a Symbol' do
        before :all do
          @return = DataMapper::Query.new(@repository, @model, @options.freeze)
        end

        it { @return.should be_kind_of(DataMapper::Query) }

        it 'should set the order' do
          @return.order.should == [ DataMapper::Query::Direction.new(@model.properties[:name]) ]
        end
      end

      describe 'that is an Array containing a String' do
        before :all do
          @options[:order] = [ 'name' ]

          @return = DataMapper::Query.new(@repository, @model, @options.freeze)
        end

        it { @return.should be_kind_of(DataMapper::Query) }

        it 'should set the order' do
          @return.order.should == [ DataMapper::Query::Direction.new(@model.properties[:name]) ]
        end
      end

      describe 'that is an Array containing a Property' do
        before :all do
          @options[:order] = @model.properties.values_at(:name)

          @return = DataMapper::Query.new(@repository, @model, @options.freeze)
        end

        it { @return.should be_kind_of(DataMapper::Query) }

        it 'should set the order' do
          @return.order.should == [ DataMapper::Query::Direction.new(@model.properties[:name]) ]
        end
      end

      describe 'that is an Array containing a Property from an ancestor' do
        before :all do
          class ::Contact < User; end

          @options[:order] = User.properties.values_at(:name)

          @return = DataMapper::Query.new(@repository, Contact, @options.freeze)
        end

        it { @return.should be_kind_of(DataMapper::Query) }

        it 'should set the order' do
          @return.order.should == [ DataMapper::Query::Direction.new(User.properties[:name]) ]
        end
      end

      describe 'that is an Array containing an Operator' do
        before :all do
          @options[:order] = [ :name.asc ]

          @return = DataMapper::Query.new(@repository, @model, @options.freeze)
        end

        it { @return.should be_kind_of(DataMapper::Query) }

        it 'should set the order' do
          @return.order.should == [ DataMapper::Query::Direction.new(@model.properties[:name], :asc) ]
        end
      end

      describe 'that is an Array containing an Query::Direction' do
        before :all do
          @options[:order] = [ DataMapper::Query::Direction.new(@model.properties[:name], :asc) ]

          @return = DataMapper::Query.new(@repository, @model, @options.freeze)
        end

        it { @return.should be_kind_of(DataMapper::Query) }

        it 'should set the order' do
          @return.order.should == [ DataMapper::Query::Direction.new(@model.properties[:name], :asc) ]
        end
      end

      describe 'that is an Array containing an Query::Direction with a Property from an ancestor' do
        before :all do
          class ::Contact < User; end

          @options[:order] = [ DataMapper::Query::Direction.new(User.properties[:name], :asc) ]

          @return = DataMapper::Query.new(@repository, Contact, @options.freeze)
        end

        it { @return.should be_kind_of(DataMapper::Query) }

        it 'should set the order' do
          @return.order.should == [ DataMapper::Query::Direction.new(User.properties[:name], :asc) ]
        end
      end

      describe 'that is missing' do
        before :all do
          @return = DataMapper::Query.new(@repository, @model, @options.except(:order).freeze)
        end

        it { @return.should be_kind_of(DataMapper::Query) }

        it 'should set order to the model default order' do
          @return.order.should == @model.default_order(@repository.name)
        end
      end

      describe 'that is invalid' do
        it 'should raise an exception' do
          lambda {
            DataMapper::Query.new(@repository, @model, @options.update(:order => 'unknown'))
          }.should raise_error(ArgumentError, "+options[:order]+ entry \"unknown\" does not map to a property in #{@model}")
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
          }.should raise_error(ArgumentError, "+options[:order]+ entry \"unknown\" does not map to a property in #{@model}")
        end
      end

      describe 'that is an Array containing an invalid object' do
        it 'should raise an exception' do
          lambda {
            DataMapper::Query.new(@repository, @model, @options.update(:order => [ 1 ]))
          }.should raise_error(ArgumentError, '+options[:order]+ entry 1 of an unsupported object Fixnum')
        end
      end

      describe 'that contains a Query::Direction with a property that is not part of the model' do
        before :all do
          @property = DataMapper::Property.new(@model, :unknown, String)
          @direction = DataMapper::Query::Direction.new(@property, :desc)
        end

        it 'should raise an exception' do
          lambda {
            DataMapper::Query.new(@repository, @model, @options.update(:order => [ @direction ]))
          }.should raise_error(ArgumentError, "+options[:order]+ entry :unknown does not map to a property in #{@model}")
        end
      end

      describe 'that contains a Query::Operator with a target that is not part of the model' do
        it 'should raise an exception' do
          lambda {
            DataMapper::Query.new(@repository, @model, @options.update(:order => [ :unknown.desc ]))
          }.should raise_error(ArgumentError, "+options[:order]+ entry :unknown does not map to a property in #{@model}")
        end
      end

      describe 'that contains a Query::Operator with an unknown operator' do
        it 'should raise an exception' do
          lambda {
            DataMapper::Query.new(@repository, @model, @options.update(:order => [ :name.gt ]))
          }.should raise_error(ArgumentError, '+options[:order]+ entry #<DataMapper::Query::Operator @target=:name @operator=:gt> used an invalid operator gt')
        end
      end

      describe 'that contains a Property that is not part of the model' do
        before :all do
          @property = DataMapper::Property.new(@model, :unknown, String)
        end

        it 'should raise an exception' do
          lambda {
            DataMapper::Query.new(@repository, @model, @options.update(:order => [ @property ]))
          }.should raise_error(ArgumentError, "+options[:order]+ entry :unknown does not map to a property in #{@model}")
        end
      end

      describe 'that contains a Symbol that is not for a Property in the model' do
        it 'should raise an exception' do
          lambda {
            DataMapper::Query.new(@repository, @model, @options.update(:order => [ :unknown ]))
          }.should raise_error(ArgumentError, "+options[:order]+ entry :unknown does not map to a property in #{@model}")
        end
      end

      describe 'that contains a String that is not for a Property in the model' do
        it 'should raise an exception' do
          lambda {
            DataMapper::Query.new(@repository, @model, @options.update(:order => [ 'unknown' ]))
          }.should raise_error(ArgumentError, "+options[:order]+ entry \"unknown\" does not map to a property in #{@model}")
        end
      end
    end

    describe 'with a unique option' do
      describe 'that is valid' do
        before :all do
          @return = DataMapper::Query.new(@repository, @model, @options.freeze)
        end

        it { @return.should be_kind_of(DataMapper::Query) }

        it 'should set the unique? flag' do
          @return.unique?.should == @unique
        end
      end

      describe 'that is missing' do
        before :all do
          @return = DataMapper::Query.new(@repository, @model, @options.except(:unique, :links).freeze)
        end

        it { @return.should be_kind_of(DataMapper::Query) }

        it 'should set the query to not be unique' do
          @return.should_not be_unique
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
        before :all do
          @return = DataMapper::Query.new(@repository, @model, @options.freeze)
        end

        it { @return.should be_kind_of(DataMapper::Query) }

        it 'should set the add_reversed? flag' do
          @return.add_reversed?.should == @add_reversed
        end
      end

      describe 'that is missing' do
        before :all do
          @return = DataMapper::Query.new(@repository, @model, @options.except(:add_reversed).freeze)
        end

        it { @return.should be_kind_of(DataMapper::Query) }

        it 'should set the query to not add in reverse order' do
          # TODO: think about renaming the flag to not sound 'clumsy'
          @return.should_not be_add_reversed
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
        before :all do
          @return = DataMapper::Query.new(@repository, @model, @options.freeze)
        end

        it { @return.should be_kind_of(DataMapper::Query) }

        it 'should set the reload? flag' do
          @return.reload?.should == @reload
        end
      end

      describe 'that is missing' do
        before :all do
          @return = DataMapper::Query.new(@repository, @model, @options.except(:reload).freeze)
        end

        it { @return.should be_kind_of(DataMapper::Query) }

        it 'should set the query to not reload' do
          @return.should_not be_reload
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
        before :all do
          @options.update(@options.delete(:conditions))

          @return = DataMapper::Query.new(@repository, @model, @options.freeze)
        end

        it { @return.should be_kind_of(DataMapper::Query) }

        it 'should set the conditions' do
          @return.conditions.should ==
            DataMapper::Query::Conditions::Operation.new(
              :and,
              DataMapper::Query::Conditions::Comparison.new(
                :eql,
                @model.properties[:name],
                @conditions[:name]
              )
            )
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
      before :all do
        @return = DataMapper::Query.new(@repository, @model)
      end

      it { @return.should be_kind_of(DataMapper::Query) }

      it 'should set options to an empty Hash' do
        @return.options.should == {}
      end
    end
  end
end

# instance methods
describe DataMapper::Query do
  before :all do
    class ::User
      include DataMapper::Resource

      property :name,        String, :key => true
      property :citizenship, String

      belongs_to :referrer, self, :required => false
      has n, :referrals,    self, :inverse => :referrer
      has n, :grandparents, self, :through => :referrals, :via => :referrer
    end

    class ::Other
      include DataMapper::Resource

      property :id, Serial
    end

    # TODO: figure out how to remove these
    User.send(:assert_valid)
    Other.send(:assert_valid)

    @repository = DataMapper::Repository.new(:default)
    @model      = User
    @options    = { :limit => 3 }
    @query      = DataMapper::Query.new(@repository, @model, @options)
    @original   = @query
  end

  before :all do
    @other_options = {
      :fields       => [ @model.properties[:name] ].freeze,
      :links        => [ @model.relationships[:referrer] ].freeze,
      :conditions   => [ 'name = ?', 'Dan Kubb' ].freeze,
      :offset       => 1,
      :limit        => 2,
      :order        => [ DataMapper::Query::Direction.new(@model.properties[:name], :desc) ].freeze,
      :unique       => true,
      :add_reversed => true,
      :reload       => true,
    }
  end

  subject { @query }

  it { should respond_to(:==) }

  describe '#==' do
    describe 'when other is equal' do
      before :all do
        @return = @query == @query
      end

      it { @return.should be_true }
    end

    describe 'when other is equivalent' do
      before :all do
        @return = @query == @query.dup
      end

      it { @return.should be_true }
    end

    DataMapper::Query::OPTIONS.each do |name|
      describe "when other has an inequalvalent #{name}" do
        before :all do
          @return = @query == @query.merge(name => @other_options[name])
        end

        it { @return.should be_false }
      end
    end

    describe 'when other is a different type of object that can be compared, and is equivalent' do
      before :all do
        @other = OpenStruct.new(
          :repository    => @query.repository,
          :model         => @query.model,
          :sorted_fields => @query.sorted_fields,
          :links         => @query.links,
          :conditions    => @query.conditions,
          :order         => @query.order,
          :limit         => @query.limit,
          :offset        => @query.offset,
          :reload?       => @query.reload?,
          :unique?       => @query.unique?,
          :add_reversed? => @query.add_reversed?
        )

        @return = @query == @other
      end

      it { @return.should be_true }
    end

    describe 'when other is a different type of object that can be compared, and is not equivalent' do
      before :all do
        @other = OpenStruct.new(
          :repository    => @query.repository,
          :model         => @query.model,
          :sorted_fields => @query.sorted_fields,
          :links         => @query.links,
          :conditions    => @query.conditions,
          :order         => @query.order,
          :limit         => @query.limit,
          :offset        => @query.offset,
          :reload?       => true,
          :unique?       => @query.unique?,
          :add_reversed? => @query.add_reversed?
        )

        @return = @query == @other
      end

      it { @return.should be_false }
    end

    describe 'when other is a different type of object that cannot be compared' do
      before :all do
        @return = @query == 'invalid'
      end

      it { @return.should be_false }
    end
  end

  it { should respond_to(:conditions) }

  describe '#conditions' do
    before :all do
      @query.update(:name => 'Dan Kubb')

      @return = @query.conditions
    end

    it { @return.should be_kind_of(DataMapper::Query::Conditions::AndOperation) }

    it 'should return expected value' do
      @return.should ==
        DataMapper::Query::Conditions::Operation.new(
          :and,
          DataMapper::Query::Conditions::Comparison.new(
            :eql,
            @model.properties[:name],
            'Dan Kubb'
          )
        )
    end
  end

  [ :difference, :- ].each do |method|
    it { should respond_to(method) }

    describe "##{method}" do
      supported_by :all do
        before :all do
          @key = @model.key(@repository.name)

          @self_relationship = DataMapper::Associations::OneToMany::Relationship.new(
            :self,
            @model,
            @model,
            {
              :child_key              => @key.map { |p| p.name },
              :parent_key             => @key.map { |p| p.name },
              :child_repository_name  => @repository,
              :parent_repository_name => @repository,
            }
          )

          10.times do |n|
            @model.create(:name => "#{@model} #{n}")
          end
        end

        subject { @query.send(method, @other) }

        describe 'with other matching everything' do
          before do
            @query = DataMapper::Query.new(@repository, @model, :name => 'Dan Kubb')
            @other = DataMapper::Query.new(@repository, @model)

            @expected = DataMapper::Query::Conditions::Comparison.new(:eql, @model.properties[:name], 'Dan Kubb')
          end

          it { should be_kind_of(DataMapper::Query) }

          it { should_not equal(@query) }

          it { should_not equal(@other) }

          it 'should factor out the operation matching everything' do
            subject.conditions.should == @expected
          end
        end

        describe 'with self matching everything' do
          before do
            @query = DataMapper::Query.new(@repository, @model)
            @other = DataMapper::Query.new(@repository, @model, :name => 'Dan Kubb')

            @expected = DataMapper::Query::Conditions::Operation.new(:not,
              DataMapper::Query::Conditions::Comparison.new(:eql, @model.properties[:name], 'Dan Kubb')
            )
          end

          it { should be_kind_of(DataMapper::Query) }

          it { should_not equal(@query) }

          it { should_not equal(@other) }

          it 'should factor out the operation matching everything, and negate the other' do
            subject.conditions.should == @expected
          end
        end

        describe 'with self having a limit' do
          before do
            @query = DataMapper::Query.new(@repository, @model, :limit => 5)
            @other = DataMapper::Query.new(@repository, @model, :name => 'Dan Kubb')

            @expected = DataMapper::Query::Conditions::Operation.new(:and,
              DataMapper::Query::Conditions::Comparison.new(:in, @self_relationship, @model.all(@query.merge(:fields => @key))),
              DataMapper::Query::Conditions::Operation.new(:not,
                DataMapper::Query::Conditions::Comparison.new(:eql, @model.properties[:name], 'Dan Kubb')
              )
            )
          end

          it { should_not equal(@query) }

          it { should_not equal(@other) }

          it 'should put each query into a subquery and AND them together, and negate the other' do
            subject.conditions.should == @expected
          end
        end

        describe 'with other having a limit' do
          before do
            @query = DataMapper::Query.new(@repository, @model, :name => 'Dan Kubb')
            @other = DataMapper::Query.new(@repository, @model, :limit => 5)

            @expected = DataMapper::Query::Conditions::Operation.new(:and,
              DataMapper::Query::Conditions::Comparison.new(:eql, @model.properties[:name], 'Dan Kubb'),
              DataMapper::Query::Conditions::Operation.new(:not,
                DataMapper::Query::Conditions::Comparison.new(:in, @self_relationship, @model.all(@other.merge(:fields => @key)))
              )
            )
          end

          it { should_not equal(@query) }

          it { should_not equal(@other) }

          it 'should put each query into a subquery and AND them together, and negate the other' do
            subject.conditions.should == @expected
          end
        end

        describe 'with self having an offset > 0' do
          before do
            @query = DataMapper::Query.new(@repository, @model, :offset => 5, :limit => 5)
            @other = DataMapper::Query.new(@repository, @model, :name => 'Dan Kubb')

            @expected = DataMapper::Query::Conditions::Operation.new(:and,
              DataMapper::Query::Conditions::Comparison.new(:in, @self_relationship, @model.all(@query.merge(:fields => @key))),
              DataMapper::Query::Conditions::Operation.new(:not,
                DataMapper::Query::Conditions::Comparison.new(:eql, @model.properties[:name], 'Dan Kubb')
              )
            )
          end

          it { should_not equal(@query) }

          it { should_not equal(@other) }

          it 'should put each query into a subquery and AND them together, and negate the other' do
            subject.conditions.should == @expected
          end
        end

        describe 'with other having an offset > 0' do
          before do
            @query = DataMapper::Query.new(@repository, @model, :name => 'Dan Kubb')
            @other = DataMapper::Query.new(@repository, @model, :offset => 5, :limit => 5)

            @expected = DataMapper::Query::Conditions::Operation.new(:and,
              DataMapper::Query::Conditions::Comparison.new(:eql, @model.properties[:name], 'Dan Kubb'),
              DataMapper::Query::Conditions::Operation.new(:not,
                DataMapper::Query::Conditions::Comparison.new(:in, @self_relationship, @model.all(@other.merge(:fields => @key)))
              )
            )
          end

          it { should_not equal(@query) }

          it { should_not equal(@other) }

          it 'should put each query into a subquery and AND them together, and negate the other' do
            subject.conditions.should == @expected
          end
        end

        describe 'with self having links' do
          before :all do
            @do_adapter = defined?(DataMapper::Adapters::DataObjectsAdapter) && @adapter.kind_of?(DataMapper::Adapters::DataObjectsAdapter)
          end

          before do
            @query = DataMapper::Query.new(@repository, @model, :links => [ :referrer ])
            @other = DataMapper::Query.new(@repository, @model, :name => 'Dan Kubb')

            @expected = DataMapper::Query::Conditions::Operation.new(:and,
              DataMapper::Query::Conditions::Comparison.new(:in, @self_relationship, @model.all(@query.merge(:fields => @key))),
              DataMapper::Query::Conditions::Operation.new(:not,
                DataMapper::Query::Conditions::Comparison.new(:eql, @model.properties[:name], 'Dan Kubb')
              )
            )
          end

          it { should_not equal(@query) }

          it { should_not equal(@other) }

          it 'should put each query into a subquery and AND them together, and negate the other query' do
            pending_if 'TODO: Fix once table aliasing works', @do_adapter do
              subject.conditions.should == @expected
            end
          end
        end

        describe 'with other having links' do
          before :all do
            @do_adapter = defined?(DataMapper::Adapters::DataObjectsAdapter) && @adapter.kind_of?(DataMapper::Adapters::DataObjectsAdapter)
          end

          before do
            @query = DataMapper::Query.new(@repository, @model, :name => 'Dan Kubb')
            @other = DataMapper::Query.new(@repository, @model, :links => [ :referrer ])

            @expected = DataMapper::Query::Conditions::Operation.new(:and,
              DataMapper::Query::Conditions::Comparison.new(:eql, @model.properties[:name], 'Dan Kubb'),
              DataMapper::Query::Conditions::Operation.new(:not,
                DataMapper::Query::Conditions::Comparison.new(:in, @self_relationship, @model.all(@other.merge(:fields => @key)))
              )
            )
          end

          it { should_not equal(@query) }

          it { should_not equal(@other) }

          it 'should put each query into a subquery and AND them together, and negate the other query' do
            pending_if 'TODO: Fix once table aliasing works', @do_adapter do
              subject.conditions.should == @expected
            end
          end
        end

        describe 'with different conditions, no links/offset/limit' do
          before do
            property = @model.properties[:name]

            @query = DataMapper::Query.new(@repository, @model, property.name => 'Dan Kubb')
            @other = DataMapper::Query.new(@repository, @model, property.name => 'John Doe')

            @query.conditions.should_not == @other.conditions

            @expected = DataMapper::Query::Conditions::Operation.new(:and,
              DataMapper::Query::Conditions::Comparison.new(:eql, property, 'Dan Kubb'),
              DataMapper::Query::Conditions::Operation.new(:not,
                DataMapper::Query::Conditions::Comparison.new(:eql, property, 'John Doe')
              )
            )
          end

          it { should be_kind_of(DataMapper::Query) }

          it { should_not equal(@query) }

          it { should_not equal(@other) }

          it 'should AND the conditions together, and negate the other query' do
            subject.conditions.should == @expected
          end
        end

        describe 'with different fields' do
          before do
            @property = @model.properties[:name]

            @query = DataMapper::Query.new(@repository, @model)
            @other = DataMapper::Query.new(@repository, @model, :fields => [ @property ])

            @query.fields.should_not == @other.fields
          end

          it { should be_kind_of(DataMapper::Query) }

          it { should_not equal(@query) }

          it { should_not equal(@other) }

          it { subject.conditions.should == DataMapper::Query::Conditions::Operation.new(:and) }

          it 'should use the other fields' do
            subject.fields.should == [ @property ]
          end
        end

        describe 'with different order' do
          before do
            @property = @model.properties[:name]

            @query = DataMapper::Query.new(@repository, @model)
            @other = DataMapper::Query.new(@repository, @model, :order => [ DataMapper::Query::Direction.new(@property, :desc) ])

            @query.order.should_not == @other.order
          end

          it { should be_kind_of(DataMapper::Query) }

          it { should_not equal(@query) }

          it { should_not equal(@other) }

          it { subject.conditions.should == DataMapper::Query::Conditions::Operation.new(:and) }

          it 'should use the other order' do
            subject.order.should == [ DataMapper::Query::Direction.new(@property, :desc) ]
          end
        end

        describe 'with different unique' do
          before do
            @query = DataMapper::Query.new(@repository, @model)
            @other = DataMapper::Query.new(@repository, @model, :unique => true)

            @query.unique?.should_not == @other.unique?
          end

          it { should be_kind_of(DataMapper::Query) }

          it { should_not equal(@query) }

          it { should_not equal(@other) }

          it { subject.conditions.should == DataMapper::Query::Conditions::Operation.new(:and) }

          it 'should use the other unique' do
            subject.unique?.should == true
          end
        end

        describe 'with different add_reversed' do
          before do
            @query = DataMapper::Query.new(@repository, @model)
            @other = DataMapper::Query.new(@repository, @model, :add_reversed => true)

            @query.add_reversed?.should_not == @other.add_reversed?
          end

          it { should be_kind_of(DataMapper::Query) }

          it { should_not equal(@query) }

          it { should_not equal(@other) }

          it { subject.conditions.should == DataMapper::Query::Conditions::Operation.new(:and) }

          it 'should use the other add_reversed' do
            subject.add_reversed?.should == true
          end
        end

        describe 'with different reload' do
          before do
            @query = DataMapper::Query.new(@repository, @model)
            @other = DataMapper::Query.new(@repository, @model, :reload => true)

            @query.reload?.should_not == @other.reload?
          end

          it { should be_kind_of(DataMapper::Query) }

          it { should_not equal(@query) }

          it { should_not equal(@other) }

          it { subject.conditions.should == DataMapper::Query::Conditions::Operation.new(:and) }

          it 'should use the other reload' do
            subject.reload?.should == true
          end
        end

        describe 'with different models' do
          before { @other = DataMapper::Query.new(@repository, Other) }

          it { method(:subject).should raise_error(ArgumentError) }
        end
      end
    end
  end

  it { should respond_to(:dup) }

  describe '#dup' do
    before :all do
      @new = @query.dup
    end

    it 'should return a Query' do
      @new.should be_kind_of(DataMapper::Query)
    end

    it 'should not equal query' do
      @new.should_not equal(@query)
    end

    it 'should eql query' do
      @new.should eql(@query)
    end

    it 'should == query' do
      @new.should == @query
    end
  end

  it { should respond_to(:eql?) }

  describe '#eql?' do
    describe 'when other is equal' do
      before :all do
        @return = @query.eql?(@query)
      end

      it { @return.should be_true }
    end

    describe 'when other is eql' do
      before :all do
        @return = @query.eql?(@query.dup)
      end

      it { @return.should be_true }
    end

    DataMapper::Query::OPTIONS.each do |name|
      describe "when other has an not eql #{name}" do
        before :all do
          @return = @query.eql?(@query.merge(name => @other_options[name]))
        end

        it { @return.should be_false }
      end
    end

    describe 'when other is a different type of object' do
      before :all do
        @other = OpenStruct.new(
          :repository    => @query.repository,
          :model         => @query.model,
          :sorted_fields => @query.sorted_fields,
          :links         => @query.links,
          :conditions    => @query.conditions,
          :order         => @query.order,
          :limit         => @query.limit,
          :offset        => @query.offset,
          :reload?       => @query.reload?,
          :unique?       => @query.unique?,
          :add_reversed? => @query.add_reversed?
        )

        @return = @query.eql?(@other)
      end

      it { @return.should be_false }
    end
  end

  it { should respond_to(:fields) }

  describe '#fields' do
    before :all do
      @return = @query.fields
    end

    it { @return.should be_kind_of(Array) }

    it 'should return expected value' do
      @return.should == [ @model.properties[:name], @model.properties[:citizenship], @model.properties[:referrer_name] ]
    end
  end

  it { should respond_to(:filter_records) }

  describe '#filter_records' do
    supported_by :all do
      before :all do
        @john = { 'name' => 'John Doe',  'referrer_name' => nil         }
        @sam  = { 'name' => 'Sam Smoot', 'referrer_name' => nil         }
        @dan  = { 'name' => 'Dan Kubb',  'referrer_name' => 'Sam Smoot' }

        @records = [ @john, @sam, @dan ]

        @query.update(:name.not => @sam['name'])

        @return = @query.filter_records(@records)
      end

      it 'should return Enumerable' do
        @return.should be_kind_of(Enumerable)
      end

      it 'should not be the records provided' do
        @return.should_not equal(@records)
      end

      it 'should return expected values' do
        @return.should == [ @dan, @john ]
      end
    end
  end

  it { should respond_to(:inspect) }

  describe '#inspect' do
    before :all do
      @return = @query.inspect
    end

    it 'should return expected value' do
      @return.should == <<-INSPECT.compress_lines
        #<DataMapper::Query
          @repository=:default
          @model=User
          @fields=[#<DataMapper::Property @model=User @name=:name>, #<DataMapper::Property @model=User @name=:citizenship>, #<DataMapper::Property @model=User @name=:referrer_name>]
          @links=[]
          @conditions=nil
          @order=[#<DataMapper::Query::Direction @target=#<DataMapper::Property @model=User @name=:name> @operator=:asc>]
          @limit=3
          @offset=0
          @reload=false
          @unique=false>
      INSPECT
    end
  end

  [ :intersection, :& ].each do |method|
    it { should respond_to(method) }

    describe "##{method}" do
      supported_by :all do
        before :all do
          @key = @model.key(@repository.name)

          @self_relationship = DataMapper::Associations::OneToMany::Relationship.new(
            :self,
            @model,
            @model,
            {
              :child_key              => @key.map { |p| p.name },
              :parent_key             => @key.map { |p| p.name },
              :child_repository_name  => @repository,
              :parent_repository_name => @repository,
            }
          )

          10.times do |n|
            @model.create(:name => "#{@model} #{n}")
          end
        end

        subject { @query.send(method, @other) }

        describe 'with equivalent query' do
          before { @other = @query.dup }

          it { should be_kind_of(DataMapper::Query) }

          it { should_not equal(@query) }

          it { should_not equal(@other) }

          it { should == @query }
        end

        describe 'with other matching everything' do
          before do
            @query = DataMapper::Query.new(@repository, @model, :name => 'Dan Kubb')
            @other = DataMapper::Query.new(@repository, @model)
          end

          it { should be_kind_of(DataMapper::Query) }

          it { should_not equal(@query) }

          it { should_not equal(@other) }

          it 'should factor out the operation matching everything' do
            pending 'TODO: compress Query#conditions for proper comparison' do
              should == DataMapper::Query.new(@repository, @model, :name => 'Dan Kubb')
            end
          end
        end

        describe 'with self matching everything' do
          before do
            @query = DataMapper::Query.new(@repository, @model)
            @other = DataMapper::Query.new(@repository, @model, :name => 'Dan Kubb')
          end

          it { should be_kind_of(DataMapper::Query) }

          it { should_not equal(@query) }

          it { should_not equal(@other) }

          it 'should factor out the operation matching everything' do
            pending 'TODO: compress Query#conditions for proper comparison' do
              should == DataMapper::Query.new(@repository, @model, :name => 'Dan Kubb')
            end
          end
        end

        describe 'with self having a limit' do
          before do
            @query = DataMapper::Query.new(@repository, @model, :limit => 5)
            @other = DataMapper::Query.new(@repository, @model, :name => 'Dan Kubb')

            @expected = DataMapper::Query::Conditions::Operation.new(:and,
              DataMapper::Query::Conditions::Comparison.new(:in,  @self_relationship,       @model.all(@query.merge(:fields => @key))),
              DataMapper::Query::Conditions::Comparison.new(:eql, @model.properties[:name], 'Dan Kubb')
            )
          end

          it { should_not equal(@query) }

          it { should_not equal(@other) }

          it 'should put each query into a subquery and AND them together' do
            subject.conditions.should == @expected
          end
        end

        describe 'with other having a limit' do
          before do
            @query = DataMapper::Query.new(@repository, @model, :name => 'Dan Kubb')
            @other = DataMapper::Query.new(@repository, @model, :limit => 5)

            @expected = DataMapper::Query::Conditions::Operation.new(:and,
              DataMapper::Query::Conditions::Comparison.new(:eql, @model.properties[:name], 'Dan Kubb'),
              DataMapper::Query::Conditions::Comparison.new(:in,  @self_relationship,       @model.all(@other.merge(:fields => @key)))
            )
          end

          it { should_not equal(@query) }

          it { should_not equal(@other) }

          it 'should put each query into a subquery and AND them together' do
            subject.conditions.should == @expected
          end
        end

        describe 'with self having an offset > 0' do
          before do
            @query = DataMapper::Query.new(@repository, @model, :offset => 5, :limit => 5)
            @other = DataMapper::Query.new(@repository, @model, :name => 'Dan Kubb')

            @expected = DataMapper::Query::Conditions::Operation.new(:and,
              DataMapper::Query::Conditions::Comparison.new(:in,  @self_relationship,       @model.all(@query.merge(:fields => @key))),
              DataMapper::Query::Conditions::Comparison.new(:eql, @model.properties[:name], 'Dan Kubb')
            )
          end

          it { should_not equal(@query) }

          it { should_not equal(@other) }

          it 'should put each query into a subquery and AND them together' do
            subject.conditions.should == @expected
          end
        end

        describe 'with other having an offset > 0' do
          before do
            @query = DataMapper::Query.new(@repository, @model, :name => 'Dan Kubb')
            @other = DataMapper::Query.new(@repository, @model, :offset => 5, :limit => 5)

            @expected = DataMapper::Query::Conditions::Operation.new(:and,
              DataMapper::Query::Conditions::Comparison.new(:eql, @model.properties[:name], 'Dan Kubb'),
              DataMapper::Query::Conditions::Comparison.new(:in,  @self_relationship,        @model.all(@other.merge(:fields => @key)))
            )
          end

          it { should_not equal(@query) }

          it { should_not equal(@other) }

          it 'should put each query into a subquery and AND them together' do
            subject.conditions.should == @expected
          end
        end

        describe 'with self having links' do
          before :all do
            @do_adapter = defined?(DataMapper::Adapters::DataObjectsAdapter) && @adapter.kind_of?(DataMapper::Adapters::DataObjectsAdapter)
          end

          before do
            @query = DataMapper::Query.new(@repository, @model, :links => [ :referrer ])
            @other = DataMapper::Query.new(@repository, @model, :name => 'Dan Kubb')

            @expected = DataMapper::Query::Conditions::Operation.new(:and,
              DataMapper::Query::Conditions::Comparison.new(:in,  @self_relationship,       @model.all(@query.merge(:fields => @key))),
              DataMapper::Query::Conditions::Comparison.new(:eql, @model.properties[:name], 'Dan Kubb')
            )
          end

          it { should_not equal(@query) }

          it { should_not equal(@other) }

          it 'should put each query into a subquery and AND them together' do
            pending_if 'TODO: Fix once table aliasing works', @do_adapter do
              subject.conditions.should == @expected
            end
          end
        end

        describe 'with other having links' do
          before :all do
            @do_adapter = defined?(DataMapper::Adapters::DataObjectsAdapter) && @adapter.kind_of?(DataMapper::Adapters::DataObjectsAdapter)
          end

          before do
            @query = DataMapper::Query.new(@repository, @model, :name => 'Dan Kubb')
            @other = DataMapper::Query.new(@repository, @model, :links => [ :referrer ])

            @expected = DataMapper::Query::Conditions::Operation.new(:and,
              DataMapper::Query::Conditions::Comparison.new(:eql, @model.properties[:name], 'Dan Kubb'),
              DataMapper::Query::Conditions::Comparison.new(:in,  @self_relationship,       @model.all(@other.merge(:fields => @key)))
            )
          end

          it { should_not equal(@query) }

          it { should_not equal(@other) }

          it 'should put each query into a subquery and AND them together' do
            pending_if 'TODO: Fix once table aliasing works', @do_adapter do
              subject.conditions.should == @expected
            end
          end
        end

        describe 'with different conditions, no links/offset/limit' do
          before do
            property = @model.properties[:name]

            @query = DataMapper::Query.new(@repository, @model, property.name => 'Dan Kubb')
            @other = DataMapper::Query.new(@repository, @model, property.name => 'John Doe')

            @query.conditions.should_not == @other.conditions

            @expected = DataMapper::Query::Conditions::Operation.new(:and,
              DataMapper::Query::Conditions::Comparison.new(:eql, property, 'Dan Kubb'),
              DataMapper::Query::Conditions::Comparison.new(:eql, property, 'John Doe')
            )
          end

          it { should be_kind_of(DataMapper::Query) }

          it { should_not equal(@query) }

          it { should_not equal(@other) }

          it 'should AND the conditions together' do
            subject.conditions.should == @expected
          end
        end

        describe 'with different fields' do
          before do
            @property = @model.properties[:name]

            @query = DataMapper::Query.new(@repository, @model)
            @other = DataMapper::Query.new(@repository, @model, :fields => [ @property ])

            @query.fields.should_not == @other.fields
          end

          it { should be_kind_of(DataMapper::Query) }

          it { should_not equal(@query) }

          it { should_not equal(@other) }

          it { subject.conditions.should be_nil }

          it 'should use the other fields' do
            subject.fields.should == [ @property ]
          end
        end

        describe 'with different order' do
          before do
            @property = @model.properties[:name]

            @query = DataMapper::Query.new(@repository, @model)
            @other = DataMapper::Query.new(@repository, @model, :order => [ DataMapper::Query::Direction.new(@property, :desc) ])

            @query.order.should_not == @other.order
          end

          it { should be_kind_of(DataMapper::Query) }

          it { should_not equal(@query) }

          it { should_not equal(@other) }

          it { subject.conditions.should be_nil }

          it 'should use the other order' do
            subject.order.should == [ DataMapper::Query::Direction.new(@property, :desc) ]
          end
        end

        describe 'with different unique' do
          before do
            @query = DataMapper::Query.new(@repository, @model)
            @other = DataMapper::Query.new(@repository, @model, :unique => true)

            @query.unique?.should_not == @other.unique?
          end

          it { should be_kind_of(DataMapper::Query) }

          it { should_not equal(@query) }

          it { should_not equal(@other) }

          it { subject.conditions.should be_nil }

          it 'should use the other unique' do
            subject.unique?.should == true
          end
        end

        describe 'with different add_reversed' do
          before do
            @query = DataMapper::Query.new(@repository, @model)
            @other = DataMapper::Query.new(@repository, @model, :add_reversed => true)

            @query.add_reversed?.should_not == @other.add_reversed?
          end

          it { should be_kind_of(DataMapper::Query) }

          it { should_not equal(@query) }

          it { should_not equal(@other) }

          it { subject.conditions.should be_nil }

          it 'should use the other add_reversed' do
            subject.add_reversed?.should == true
          end
        end

        describe 'with different reload' do
          before do
            @query = DataMapper::Query.new(@repository, @model)
            @other = DataMapper::Query.new(@repository, @model, :reload => true)

            @query.reload?.should_not == @other.reload?
          end

          it { should be_kind_of(DataMapper::Query) }

          it { should_not equal(@query) }

          it { should_not equal(@other) }

          it 'should use the other reload' do
            subject.reload?.should == true
          end
        end

        describe 'with different models' do
          before { @other = DataMapper::Query.new(@repository, Other) }

          it { method(:subject).should raise_error(ArgumentError) }
        end
      end
    end
  end

  it { should respond_to(:limit) }

  describe '#limit' do
    before :all do
      @return = @query.limit
    end

    it { @return.should be_kind_of(Integer) }

    it 'should return expected value' do
      @return.should == 3
    end
  end

  it { should respond_to(:limit_records) }

  describe '#limit_records' do
    supported_by :all do
      before :all do
        @john = { 'name' => 'John Doe',  'referrer_name' => nil         }
        @sam  = { 'name' => 'Sam Smoot', 'referrer_name' => nil         }
        @dan  = { 'name' => 'Dan Kubb',  'referrer_name' => 'Sam Smoot' }

        @records = [ @john, @sam, @dan ]

        @query.update(:limit => 1, :offset => 1)

        @return = @query.limit_records(@records)
      end

      it 'should return Enumerable' do
        @return.should be_kind_of(Enumerable)
      end

      it 'should not be the records provided' do
        @return.should_not equal(@records)
      end

      it 'should return expected values' do
        @return.should == [ @sam ]
      end
    end
  end

  it { should respond_to(:links) }

  describe '#links' do
    before :all do
      @return = @query.links
    end

    it { @return.should be_kind_of(Array) }

    it { @return.should be_empty }
  end

  it { should respond_to(:match_records) }

  describe '#match_records' do
    supported_by :all do
      before :all do
        @john = { 'name' => 'John Doe',  'referrer_name' => nil         }
        @sam  = { 'name' => 'Sam Smoot', 'referrer_name' => nil         }
        @dan  = { 'name' => 'Dan Kubb',  'referrer_name' => 'Sam Smoot' }

        @records = [ @john, @sam, @dan ]

        @query.update(:name.not => @sam['name'])

        @return = @query.match_records(@records)
      end

      it 'should return Enumerable' do
        @return.should be_kind_of(Enumerable)
      end

      it 'should not be the records provided' do
        @return.should_not equal(@records)
      end

      it 'should return expected values' do
        @return.should == [ @john, @dan ]
      end
    end
  end

  it { should respond_to(:merge) }

  describe '#merge' do
    describe 'with a Hash' do
      before do
        @return = @query.merge({ :limit => 202 })
      end

      it 'does not affect the receiver' do
        @query.options[:limit].should == 3
      end
    end

    describe 'with a Query' do
      before do
        @other  = DataMapper::Query.new(@repository, @model, @options.update(@other_options))
        @return = @query.merge(@other)
      end

      it 'does not affect the receiver' do
        @query.options[:limit].should == 3
      end
    end
  end

  it { should respond_to(:model) }

  describe '#model' do
    before :all do
      @return = @query.model
    end

    it { @return.should be_kind_of(Class) }

    it 'should return expected value' do
      @return.should == @model
    end
  end

  it { should respond_to(:offset) }

  describe '#offset' do
    before :all do
      @return = @query.offset
    end

    it { @return.should be_kind_of(Integer) }

    it 'should return expected value' do
      @return.should == 0
    end
  end

  it { should respond_to(:order) }

  describe '#order' do
    before :all do
      @return = @query.order
    end

    it { @return.should be_kind_of(Array) }

    it 'should return expected value' do
      @return.should == [ DataMapper::Query::Direction.new(@model.properties[:name]) ]
    end
  end

  it { should respond_to(:raw?) }

  describe '#raw?' do
    describe 'when the query contains raw conditions' do
      before :all do
        @query.update(:conditions => [ 'name = ?', 'Dan Kubb' ])
      end

      it { should be_raw }
    end

    describe 'when the query does not contain raw conditions' do
      it { should_not be_raw }
    end
  end

  it { should respond_to(:relative) }

  describe '#relative' do
    describe 'with a Hash' do
      describe 'that is empty' do
        before :all do
          @return = @query.relative({})
        end

        it { @return.should be_kind_of(DataMapper::Query) }

        it 'should not return self' do
          @return.should_not equal(@query)
        end

        it 'should return a copy' do
          @return.should be_eql(@query)
        end
      end

      describe 'using different options' do
        before :all do
          @return = @query.relative(@other_options)
        end

        it { @return.should be_kind_of(DataMapper::Query) }

        it 'should not return self' do
          @return.should_not equal(@original)
        end

        it 'should update the fields' do
          @return.fields.should == @other_options[:fields]
        end

        it 'should update the links' do
          @return.links.should == @other_options[:links]
        end

        it 'should update the conditions' do
          @return.conditions.should == DataMapper::Query::Conditions::Operation.new(:and, [ 'name = ?', [ 'Dan Kubb' ] ])
        end

        it 'should update the offset' do
          @return.offset.should == @other_options[:offset]
        end

        it 'should update the limit' do
          @return.limit.should == @other_options[:limit]
        end

        it 'should update the order' do
          @return.order.should == @other_options[:order]
        end

        it 'should update the unique' do
          @return.unique?.should == @other_options[:unique]
        end

        it 'should update the add_reversed' do
          @return.add_reversed?.should == @other_options[:add_reversed]
        end

        it 'should update the reload' do
          @return.reload?.should == @other_options[:reload]
        end
      end

      describe 'using extra options' do
        before :all do
          @options = { :name => 'Dan Kubb' }

          @return = @query.relative(@options)
        end

        it { @return.should be_kind_of(DataMapper::Query) }

        it 'should not return self' do
          @return.should_not equal(@original)
        end

        it 'should update the conditions' do
          @return.conditions.should ==
            DataMapper::Query::Conditions::Operation.new(
              :and,
              DataMapper::Query::Conditions::Comparison.new(
                :eql,
                @model.properties[:name],
                @options[:name]
              )
            )
        end
      end

      describe 'using an offset when query offset is greater than 0' do
        before :all do
          @query = @query.update(:offset => 1, :limit => 2)

          @return = @query.relative(:offset => 1)
        end

        it { @return.should be_kind_of(DataMapper::Query) }

        it 'should not return self' do
          @return.should_not equal(@original)
        end

        it 'should update the offset to be relative to the original offset' do
          @return.offset.should == 2
        end
      end

      describe 'using an limit when query limit specified' do
        before :all do
          @query = @query.update(:offset => 1, :limit => 2)

          @return = @query.relative(:limit => 1)
        end

        it { @return.should be_kind_of(DataMapper::Query) }

        it 'should not return self' do
          @return.should_not equal(@original)
        end

        it 'should update the limit' do
          @return.limit.should == 1
        end
      end
    end
  end

  it { should respond_to(:reload?) }

  describe '#reload?' do
    describe 'when the query should reload' do
      before :all do
        @query.update(:reload => true)
      end

      it { should be_reload }
    end

    describe 'when the query should not reload' do
      it { should_not be_reload }
    end
  end

  it { should respond_to(:repository) }

  describe '#repository' do
    before :all do
      @return = @query.repository
    end

    it { @return.should be_kind_of(DataMapper::Repository) }

    it 'should return expected value' do
      @return.should == @repository
    end
  end

  it { should respond_to(:reverse) }

  describe '#reverse' do
    before :all do
      @return = @query.reverse
    end

    it { @return.should be_kind_of(DataMapper::Query) }

    it 'should copy the Query' do
      @return.should_not equal(@original)
    end

    # TODO: push this into dup spec
    it 'should not reference original order' do
      @return.order.should_not equal(@original.order)
    end

    it 'should have a reversed order' do
      @return.order.should == [ DataMapper::Query::Direction.new(@model.properties[:name], :desc) ]
    end

    [ :repository, :model, :fields, :links, :conditions, :offset, :limit, :unique?, :add_reversed?, :reload? ].each do |attribute|
      it "should have an equivalent #{attribute}" do
        @return.send(attribute).should == @original.send(attribute)
      end
    end
  end

  it { should respond_to(:reverse!) }

  describe '#reverse!' do
    before :all do
      @return = @query.reverse!
    end

    it { @return.should be_kind_of(DataMapper::Query) }

    it { @return.should equal(@original) }

    it 'should have a reversed order' do
      @return.order.should == [ DataMapper::Query::Direction.new(@model.properties[:name], :desc) ]
    end
  end

  [ :slice, :[] ].each do |method|
    it { should respond_to(method) }

    describe "##{method}" do
      describe 'with a positive offset' do
        before :all do
          @query = @query.update(:offset => 1, :limit => 2)

          @return = @query.send(method, 1)
        end

        it { @return.should be_kind_of(DataMapper::Query) }

        it 'should not return self' do
          @return.should_not equal(@original)
        end

        it 'should update the offset to be relative to the original offset' do
          @return.offset.should == 2
        end

        it 'should update the limit to 1' do
          @return.limit.should == 1
        end
      end

      describe 'with a positive offset and length' do
        before :all do
          @query = @query.update(:offset => 1, :limit => 2)

          @return = @query.send(method, 1, 1)
        end

        it { @return.should be_kind_of(DataMapper::Query) }

        it 'should not return self' do
          @return.should_not equal(@original)
        end

        it 'should update the offset to be relative to the original offset' do
          @return.offset.should == 2
        end

        it 'should update the limit' do
          @return.limit.should == 1
        end
      end

      describe 'with a positive range' do
        before :all do
          @query = @query.update(:offset => 1, :limit => 3)

          @return = @query.send(method, 1..2)
        end

        it { @return.should be_kind_of(DataMapper::Query) }

        it 'should not return self' do
          @return.should_not equal(@original)
        end

        it 'should update the offset to be relative to the original offset' do
          @return.offset.should == 2
        end

        it 'should update the limit' do
          @return.limit.should == 2
        end
      end

      describe 'with a negative offset' do
        before :all do
          @query = @query.update(:offset => 1, :limit => 2)

          @return = @query.send(method, -1)
        end

        it { @return.should be_kind_of(DataMapper::Query) }

        it 'should not return self' do
          @return.should_not equal(@original)
        end

        it 'should update the offset to be relative to the original offset' do
          pending "TODO: update Query##{method} handle negative offset" do
            @return.offset.should == 2
          end
        end

        it 'should update the limit to 1' do
          @return.limit.should == 1
        end
      end

      describe 'with a negative offset and length' do
        before :all do
          @query = @query.update(:offset => 1, :limit => 2)

          @return = @query.send(method, -1, 1)
        end

        it { @return.should be_kind_of(DataMapper::Query) }

        it 'should not return self' do
          @return.should_not equal(@original)
        end

        it 'should update the offset to be relative to the original offset' do
          pending "TODO: update Query##{method} handle negative offset and length" do
            @return.offset.should == 2
          end
        end

        it 'should update the limit to 1' do
          @return.limit.should == 1
        end
      end

      describe 'with a negative range' do
        before :all do
          @query = @query.update(:offset => 1, :limit => 3)

          rescue_if "TODO: update Query##{method} handle negative range" do
            @return = @query.send(method, -2..-1)
          end
        end

        before do
          pending_if "TODO: update Query##{method} handle negative range", !defined?(@return)
        end

        it { @return.should be_kind_of(DataMapper::Query) }

        it 'should not return self' do
          @return.should_not equal(@original)
        end

        it 'should update the offset to be relative to the original offset' do
          @return.offset.should == 2
        end

        it 'should update the limit to 1' do
          @return.limit.should == 2
        end
      end

      describe 'with an offset not within range' do
        before :all do
          @query = @query.update(:offset => 1, :limit => 3)
        end

        it 'should raise an exception' do
          lambda {
            @query.send(method, 12)
          }.should raise_error(RangeError, 'offset 12 and limit 1 are outside allowed range')
        end
      end

      describe 'with an offset and length not within range' do
        before :all do
          @query = @query.update(:offset => 1, :limit => 3)
        end

        it 'should raise an exception' do
          lambda {
            @query.send(method, 12, 1)
          }.should raise_error(RangeError, 'offset 12 and limit 1 are outside allowed range')
        end
      end

      describe 'with a range not within range' do
        before :all do
          @query = @query.update(:offset => 1, :limit => 3)
        end

        it 'should raise an exception' do
          lambda {
            @query.send(method, 12..12)
          }.should raise_error(RangeError, 'offset 12 and limit 1 are outside allowed range')
        end
      end

      describe 'with invalid arguments' do
        it 'should raise an exception' do
          lambda {
            @query.send(method, 'invalid')
          }.should raise_error(ArgumentError, 'arguments may be 1 or 2 Integers, or 1 Range object, was: ["invalid"]')
        end
      end
    end
  end

  it { should respond_to(:slice!) }

  describe '#slice!' do
    describe 'with a positive offset' do
      before :all do
        @query = @query.update(:offset => 1, :limit => 2)

        @return = @query.slice!(1)
      end

      it { @return.should be_kind_of(DataMapper::Query) }

      it 'should return self' do
        @return.should equal(@original)
      end

      it 'should update the offset to be relative to the original offset' do
        @return.offset.should == 2
      end

      it 'should update the limit to 1' do
        @return.limit.should == 1
      end
    end

    describe 'with a positive offset and length' do
      before :all do
        @query = @query.update(:offset => 1, :limit => 2)

        @return = @query.slice!(1, 1)
      end

      it { @return.should be_kind_of(DataMapper::Query) }

      it 'should return self' do
        @return.should equal(@original)
      end

      it 'should update the offset to be relative to the original offset' do
        @return.offset.should == 2
      end

      it 'should update the limit' do
        @return.limit.should == 1
      end
    end

    describe 'with a positive range' do
      before :all do
        @query = @query.update(:offset => 1, :limit => 3)

        @return = @query.slice!(1..2)
      end

      it { @return.should be_kind_of(DataMapper::Query) }

      it 'should return self' do
        @return.should equal(@original)
      end

      it 'should update the offset to be relative to the original offset' do
        @return.offset.should == 2
      end

      it 'should update the limit' do
        @return.limit.should == 2
      end
    end

    describe 'with a negative offset' do
      before :all do
        @query = @query.update(:offset => 1, :limit => 2)

        @return = @query.slice!(-1)
      end

      it { @return.should be_kind_of(DataMapper::Query) }

      it 'should return self' do
        @return.should equal(@original)
      end

      it 'should update the offset to be relative to the original offset' do
        pending 'TODO: update Query#slice! handle negative offset' do
          @return.offset.should == 2
        end
      end

      it 'should update the limit to 1' do
        @return.limit.should == 1
      end
    end

    describe 'with a negative offset and length' do
      before :all do
        @query = @query.update(:offset => 1, :limit => 2)

        @return = @query.slice!(-1, 1)
      end

      it { @return.should be_kind_of(DataMapper::Query) }

      it 'should return self' do
        @return.should equal(@original)
      end

      it 'should update the offset to be relative to the original offset' do
        pending 'TODO: update Query#slice! handle negative offset and length' do
          @return.offset.should == 2
        end
      end

      it 'should update the limit to 1' do
        @return.limit.should == 1
      end
    end

    describe 'with a negative range' do
      before :all do
        @query = @query.update(:offset => 1, :limit => 3)

        rescue_if 'TODO: update Query#slice! handle negative range' do
          @return = @query.slice!(-2..-1)
        end
      end

      before do
        pending_if 'TODO: update Query#slice! handle negative range', !defined?(@return)
      end

      it { @return.should be_kind_of(DataMapper::Query) }

      it 'should return self' do
        @return.should equal(@original)
      end

      it 'should update the offset to be relative to the original offset' do
        @return.offset.should == 2
      end

      it 'should update the limit to 1' do
        @return.limit.should == 2
      end
    end

    describe 'with an offset not within range' do
      before :all do
        @query = @query.update(:offset => 1, :limit => 3)
      end

      it 'should raise an exception' do
        lambda {
          @query.slice!(12)
        }.should raise_error(RangeError, 'offset 12 and limit 1 are outside allowed range')
      end
    end

    describe 'with an offset and length not within range' do
      before :all do
        @query = @query.update(:offset => 1, :limit => 3)
      end

      it 'should raise an exception' do
        lambda {
          @query.slice!(12, 1)
        }.should raise_error(RangeError, 'offset 12 and limit 1 are outside allowed range')
      end
    end

    describe 'with a range not within range' do
      before :all do
        @query = @query.update(:offset => 1, :limit => 3)
      end

      it 'should raise an exception' do
        lambda {
          @query.slice!(12..12)
        }.should raise_error(RangeError, 'offset 12 and limit 1 are outside allowed range')
      end
    end

    describe 'with invalid arguments' do
      it 'should raise an exception' do
        lambda {
          @query.slice!('invalid')
        }.should raise_error(ArgumentError, 'arguments may be 1 or 2 Integers, or 1 Range object, was: ["invalid"]')
      end
    end
  end

  it { should respond_to(:sort_records) }

  describe '#sort_records' do
    supported_by :all do
      before :all do
        @john = { 'name' => 'John Doe',  'referrer_name' => nil         }
        @sam  = { 'name' => 'Sam Smoot', 'referrer_name' => nil         }
        @dan  = { 'name' => 'Dan Kubb',  'referrer_name' => 'Sam Smoot' }

        @records = [ @john, @sam, @dan ]

        @query.update(:order => [ :name ])

        @return = @query.sort_records(@records)
      end

      it 'should return Enumerable' do
        @return.should be_kind_of(Enumerable)
      end

      it 'should not be the records provided' do
        @return.should_not equal(@records)
      end

      it 'should return expected values' do
        @return.should == [ @dan, @john, @sam ]
      end
    end
  end

  [ :union, :|, :+ ].each do |method|
    it { should respond_to(method) }

    describe "##{method}" do
      supported_by :all do
        before :all do
          @key = @model.key(@repository.name)

          @self_relationship = DataMapper::Associations::OneToMany::Relationship.new(
            :self,
            @model,
            @model,
            {
              :child_key              => @key.map { |p| p.name },
              :parent_key             => @key.map { |p| p.name },
              :child_repository_name  => @repository,
              :parent_repository_name => @repository,
            }
          )

          10.times do |n|
            @model.create(:name => "#{@model} #{n}")
          end
        end

        subject { @query.send(method, @other) }

        describe 'with equivalent query' do
          before { @other = @query.dup }

          it { should be_kind_of(DataMapper::Query) }

          it { should_not equal(@query) }

          it { should_not equal(@other) }

          it { should == @query }
        end

        describe 'with other matching everything' do
          before do
            @query = DataMapper::Query.new(@repository, @model, :name => 'Dan Kubb')
            @other = DataMapper::Query.new(@repository, @model)
          end

          it { should be_kind_of(DataMapper::Query) }

          it { should_not equal(@query) }

          it { should_not equal(@other) }

          it 'should match everything' do
            should == DataMapper::Query.new(@repository, @model)
          end
        end

        describe 'with self matching everything' do
          before do
            @query = DataMapper::Query.new(@repository, @model)
            @other = DataMapper::Query.new(@repository, @model, :name => 'Dan Kubb')
          end

          it { should be_kind_of(DataMapper::Query) }

          it { should_not equal(@query) }

          it { should_not equal(@other) }

          it 'should match everything' do
            should == DataMapper::Query.new(@repository, @model)
          end
        end

        describe 'with self having a limit' do
          before do
            @query = DataMapper::Query.new(@repository, @model, :limit => 5)
            @other = DataMapper::Query.new(@repository, @model, :name => 'Dan Kubb')

            @expected = DataMapper::Query::Conditions::Operation.new(:or,
              DataMapper::Query::Conditions::Comparison.new(:in,  @self_relationship,       @model.all(@query.merge(:fields => @key))),
              DataMapper::Query::Conditions::Comparison.new(:eql, @model.properties[:name], 'Dan Kubb')
            )
          end

          it { should_not equal(@query) }

          it { should_not equal(@other) }

          it 'should put each query into a subquery and OR them together' do
            subject.conditions.should == @expected
          end
        end

        describe 'with other having a limit' do
          before do
            @query = DataMapper::Query.new(@repository, @model, :name => 'Dan Kubb')
            @other = DataMapper::Query.new(@repository, @model, :limit => 5)

            @expected = DataMapper::Query::Conditions::Operation.new(:or,
              DataMapper::Query::Conditions::Comparison.new(:eql, @model.properties[:name], 'Dan Kubb'),
              DataMapper::Query::Conditions::Comparison.new(:in,  @self_relationship,       @model.all(@other.merge(:fields => @key)))
            )
          end

          it { should_not equal(@query) }

          it { should_not equal(@other) }

          it 'should put each query into a subquery and OR them together' do
            subject.conditions.should == @expected
          end
        end

        describe 'with self having an offset > 0' do
          before do
            @query = DataMapper::Query.new(@repository, @model, :offset => 5, :limit => 5)
            @other = DataMapper::Query.new(@repository, @model, :name => 'Dan Kubb')

            @expected = DataMapper::Query::Conditions::Operation.new(:or,
              DataMapper::Query::Conditions::Comparison.new(:in,  @self_relationship,       @model.all(@query.merge(:fields => @key))),
              DataMapper::Query::Conditions::Comparison.new(:eql, @model.properties[:name], 'Dan Kubb')
            )
          end

          it { should_not equal(@query) }

          it { should_not equal(@other) }

          it 'should put each query into a subquery and OR them together' do
            subject.conditions.should == @expected
          end
        end

        describe 'with other having an offset > 0' do
          before do
            @query = DataMapper::Query.new(@repository, @model, :name => 'Dan Kubb')
            @other = DataMapper::Query.new(@repository, @model, :offset => 5, :limit => 5)

            @expected = DataMapper::Query::Conditions::Operation.new(:or,
              DataMapper::Query::Conditions::Comparison.new(:eql, @model.properties[:name], 'Dan Kubb'),
              DataMapper::Query::Conditions::Comparison.new(:in,  @self_relationship,        @model.all(@other.merge(:fields => @key)))
            )
          end

          it { should_not equal(@query) }

          it { should_not equal(@other) }

          it 'should put each query into a subquery and OR them together' do
            subject.conditions.should == @expected
          end
        end

        describe 'with self having links' do
          before :all do
            @do_adapter = defined?(DataMapper::Adapters::DataObjectsAdapter) && @adapter.kind_of?(DataMapper::Adapters::DataObjectsAdapter)
          end

          before do
            @query = DataMapper::Query.new(@repository, @model, :links => [ :referrer ])
            @other = DataMapper::Query.new(@repository, @model, :name => 'Dan Kubb')

            @expected = DataMapper::Query::Conditions::Operation.new(:or,
              DataMapper::Query::Conditions::Comparison.new(:in,  @self_relationship,       @model.all(@query.merge(:fields => @key))),
              DataMapper::Query::Conditions::Comparison.new(:eql, @model.properties[:name], 'Dan Kubb')
            )
          end

          it { should_not equal(@query) }

          it { should_not equal(@other) }

          it 'should put each query into a subquery and OR them together' do
            pending_if 'TODO: Fix once table aliasing works', @do_adapter do
              subject.conditions.should == @expected
            end
          end
        end

        describe 'with other having links' do
          before :all do
            @do_adapter = defined?(DataMapper::Adapters::DataObjectsAdapter) && @adapter.kind_of?(DataMapper::Adapters::DataObjectsAdapter)
          end

          before do
            @query = DataMapper::Query.new(@repository, @model, :name => 'Dan Kubb')
            @other = DataMapper::Query.new(@repository, @model, :links => [ :referrer ])

            @expected = DataMapper::Query::Conditions::Operation.new(:or,
              DataMapper::Query::Conditions::Comparison.new(:eql, @model.properties[:name], 'Dan Kubb'),
              DataMapper::Query::Conditions::Comparison.new(:in,  @self_relationship,       @model.all(@other.merge(:fields => @key)))
            )
          end

          it { should_not equal(@query) }

          it { should_not equal(@other) }

          it 'should put each query into a subquery and OR them together' do
            pending_if 'TODO: Fix once table aliasing works', @do_adapter do
              subject.conditions.should == @expected
            end
          end
        end

        describe 'with different conditions, no links/offset/limit' do
          before do
            property = @model.properties[:name]

            @query = DataMapper::Query.new(@repository, @model, property.name => 'Dan Kubb')
            @other = DataMapper::Query.new(@repository, @model, property.name => 'John Doe')

            @query.conditions.should_not == @other.conditions

            @expected = DataMapper::Query::Conditions::Operation.new(:or,
              DataMapper::Query::Conditions::Comparison.new(:eql, property, 'Dan Kubb'),
              DataMapper::Query::Conditions::Comparison.new(:eql, property, 'John Doe')
            )
          end

          it { should be_kind_of(DataMapper::Query) }

          it { should_not equal(@query) }

          it { should_not equal(@other) }

          it 'should OR the conditions together' do
            subject.conditions.should == @expected
          end
        end

        describe 'with different fields' do
          before do
            @property = @model.properties[:name]

            @query = DataMapper::Query.new(@repository, @model)
            @other = DataMapper::Query.new(@repository, @model, :fields => [ @property ])

            @query.fields.should_not == @other.fields
          end

          it { should be_kind_of(DataMapper::Query) }

          it { should_not equal(@query) }

          it { should_not equal(@other) }

          it { subject.conditions.should be_nil }

          it 'should use the other fields' do
            subject.fields.should == [ @property ]
          end
        end

        describe 'with different order' do
          before do
            @property = @model.properties[:name]

            @query = DataMapper::Query.new(@repository, @model)
            @other = DataMapper::Query.new(@repository, @model, :order => [ DataMapper::Query::Direction.new(@property, :desc) ])

            @query.order.should_not == @other.order
          end

          it { should be_kind_of(DataMapper::Query) }

          it { should_not equal(@query) }

          it { should_not equal(@other) }

          it { subject.conditions.should be_nil }

          it 'should use the other order' do
            subject.order.should == [ DataMapper::Query::Direction.new(@property, :desc) ]
          end
        end

        describe 'with different unique' do
          before do
            @query = DataMapper::Query.new(@repository, @model)
            @other = DataMapper::Query.new(@repository, @model, :unique => true)

            @query.unique?.should_not == @other.unique?
          end

          it { should be_kind_of(DataMapper::Query) }

          it { should_not equal(@query) }

          it { should_not equal(@other) }

          it { subject.conditions.should be_nil }

          it 'should use the other unique' do
            subject.unique?.should == true
          end
        end

        describe 'with different add_reversed' do
          before do
            @query = DataMapper::Query.new(@repository, @model)
            @other = DataMapper::Query.new(@repository, @model, :add_reversed => true)

            @query.add_reversed?.should_not == @other.add_reversed?
          end

          it { should be_kind_of(DataMapper::Query) }

          it { should_not equal(@query) }

          it { should_not equal(@other) }

          it { subject.conditions.should be_nil }

          it 'should use the other add_reversed' do
            subject.add_reversed?.should == true
          end
        end

        describe 'with different reload' do
          before do
            @query = DataMapper::Query.new(@repository, @model)
            @other = DataMapper::Query.new(@repository, @model, :reload => true)

            @query.reload?.should_not == @other.reload?
          end

          it { should be_kind_of(DataMapper::Query) }

          it { should_not equal(@query) }

          it { should_not equal(@other) }

          it { subject.conditions.should be_nil }

          it 'should use the other reload' do
            subject.reload?.should == true
          end
        end

        describe 'with different models' do
          before { @other = DataMapper::Query.new(@repository, Other) }

          it { method(:subject).should raise_error(ArgumentError) }
        end
      end
    end
  end

  it { should respond_to(:unique?) }

  describe '#unique?' do
    describe 'when the query is unique' do
      before :all do
        @query.update(:unique => true)
      end

      it { should be_unique }
    end

    describe 'when the query is not unique' do
      it { should_not be_unique }
    end

    describe 'when links are provided, but unique is not specified' do
      before :all do
        @query.should_not be_unique
        @query.update(:links => [ :referrer ])
      end

      it { should be_unique }
    end

    describe 'when links are provided, but unique is false' do
      before :all do
        @query.should_not be_unique
        @query.update(:links => [ :referrer ], :unique => false)
      end

      it { should_not be_unique }
    end
  end

  it { should respond_to(:update) }

  describe '#update' do
    describe 'with a Query' do
      describe 'that is equivalent' do
        before :all do
          @other = DataMapper::Query.new(@repository, @model, @options)

          @return = @query.update(@other)
        end

        it { @return.should be_kind_of(DataMapper::Query) }

        it { @return.should equal(@original) }
      end

      describe 'that has conditions set' do
        before :all do
          @and_operation = DataMapper::Query::Conditions::Operation.new(:and)
          @or_operation  = DataMapper::Query::Conditions::Operation.new(:or)

          @and_operation << DataMapper::Query::Conditions::Comparison.new(:eql, User.properties[:name],       'Dan Kubb')
          @and_operation << DataMapper::Query::Conditions::Comparison.new(:eql, User.properties[:citizenship],'Canada')

          @or_operation << DataMapper::Query::Conditions::Comparison.new(:eql, User.properties[:name],        'Ted Han')
          @or_operation << DataMapper::Query::Conditions::Comparison.new(:eql, User.properties[:citizenship], 'USA')

          @query_one = DataMapper::Query.new(@repository, @model, :conditions => @and_operation)
          @query_two = DataMapper::Query.new(@repository, @model, :conditions => @or_operation)

          @conditions = @query_one.merge(@query_two).conditions
        end

        it { @conditions.should == DataMapper::Query::Conditions::Operation.new(:and, @and_operation, @or_operation) }
      end

      describe 'that is for an ancestor model' do
        before :all do
          class ::Contact < User; end

          @query    = DataMapper::Query.new(@repository, Contact, @options)
          @original = @query

          @other = DataMapper::Query.new(@repository, User,    @options)

          @return = @query.update(@other)
        end

        it { @return.should be_kind_of(DataMapper::Query) }

        it { @return.should equal(@original) }
      end

      describe 'using a different repository' do
        it 'should raise an exception' do
          lambda {
            @query.update(DataMapper::Query.new(DataMapper::Repository.new(:other), User))
          }.should raise_error(ArgumentError, '+other+ DataMapper::Query must be for the default repository, not other')
        end
      end

      describe 'using a different model' do
        before :all do
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
        before :all do
          @other = DataMapper::Query.new(@repository, @model, @options.update(@other_options))

          @return = @query.update(@other)
        end

        it { @return.should be_kind_of(DataMapper::Query) }

        it { @return.should equal(@original) }

        it 'should update the fields' do
          @return.fields.should == @options[:fields]
        end

        it 'should update the links' do
          @return.links.should == @options[:links]
        end

        it 'should update the conditions' do
          @return.conditions.should == DataMapper::Query::Conditions::Operation.new(:and, [ 'name = ?', [ 'Dan Kubb' ] ])
        end

        it 'should update the offset' do
          @return.offset.should == @options[:offset]
        end

        it 'should update the limit' do
          @return.limit.should == @options[:limit]
        end

        it 'should update the order' do
          @return.order.should == @options[:order]
        end

        it 'should update the unique' do
          @return.unique?.should == @options[:unique]
        end

        it 'should update the add_reversed' do
          @return.add_reversed?.should == @options[:add_reversed]
        end

        it 'should update the reload' do
          @return.reload?.should == @options[:reload]
        end
      end

      describe 'using extra options' do
        before :all do
          @options.update(:name => 'Dan Kubb')
          @other = DataMapper::Query.new(@repository, @model, @options)

          @return = @query.update(@other)
        end

        it { @return.should be_kind_of(DataMapper::Query) }

        it { @return.should equal(@original) }

        it 'should update the conditions' do
          @return.conditions.should ==
            DataMapper::Query::Conditions::Operation.new(
              :and,
              DataMapper::Query::Conditions::Comparison.new(
                :eql,
                @model.properties[:name],
                @options[:name]
              )
            )
        end
      end
    end

    describe 'with a Hash' do
      describe 'that is empty' do
        before :all do
          @copy = @query.dup
          @return = @query.update({})
        end

        it { @return.should be_kind_of(DataMapper::Query) }

        it { @return.should equal(@original) }

        it 'should not change the Query' do
          @return.should == @copy
        end
      end

      describe 'using different options' do
        before :all do
          @return = @query.update(@other_options)
        end

        it { @return.should be_kind_of(DataMapper::Query) }

        it { @return.should equal(@original) }

        it 'should update the fields' do
          @return.fields.should == @other_options[:fields]
        end

        it 'should update the links' do
          @return.links.should == @other_options[:links]
        end

        it 'should update the conditions' do
          @return.conditions.should == DataMapper::Query::Conditions::Operation.new(:and, [ 'name = ?', [ 'Dan Kubb' ] ])
        end

        it 'should update the offset' do
          @return.offset.should == @other_options[:offset]
        end

        it 'should update the limit' do
          @return.limit.should == @other_options[:limit]
        end

        it 'should update the order' do
          @return.order.should == @other_options[:order]
        end

        it 'should update the unique' do
          @return.unique?.should == @other_options[:unique]
        end

        it 'should update the add_reversed' do
          @return.add_reversed?.should == @other_options[:add_reversed]
        end

        it 'should update the reload' do
          @return.reload?.should == @other_options[:reload]
        end
      end

      describe 'using extra options' do
        before :all do
          @options = { :name => 'Dan Kubb' }

          @return = @query.update(@options)
        end

        it { @return.should be_kind_of(DataMapper::Query) }

        it { @return.should equal(@original) }

        it 'should update the conditions' do
          @return.conditions.should == DataMapper::Query::Conditions::Operation.new(
            :and,
            DataMapper::Query::Conditions::Comparison.new(
              :eql,
              @model.properties[:name],
              @options[:name]
            )
          )
        end
      end

      describe 'using raw conditions' do
        before :all do
          @query.update(:conditions => [ 'name IS NOT NULL' ])

          @return = @query.update(:conditions => [ 'name = ?', 'Dan Kubb' ])
        end

        it { @return.should be_kind_of(DataMapper::Query) }

        it { @return.should equal(@original) }

        it 'should update the conditions' do
          @return.conditions.should == DataMapper::Query::Conditions::Operation.new(
            :and,
            [ 'name IS NOT NULL' ],
            [ 'name = ?', [ 'Dan Kubb' ] ]
          )
        end
      end

      describe 'with the String key mapping to a Query::Path' do
        before :all do
          @query.links.should be_empty

          @options = { 'grandparents.name' => 'Dan Kubb' }

          @return = @query.update(@options)
        end

        it { @return.should be_kind_of(DataMapper::Query) }

        it 'should set the conditions' do
          @return.conditions.should ==
            DataMapper::Query::Conditions::Operation.new(
              :and,
              DataMapper::Query::Conditions::Comparison.new(
                :eql,
                @model.grandparents.name,
                'Dan Kubb'
              )
            )
        end

        it 'should set the links' do
          @return.links.should == [ @model.relationships[:referrals], @model.relationships[:referrer] ]
        end

        it 'should be valid' do
          @return.should be_valid
        end
      end
    end
  end
end
