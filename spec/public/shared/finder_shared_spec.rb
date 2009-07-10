share_examples_for 'Finder Interface' do
  before :all do
    %w[ @article_model @article @other @articles ].each do |ivar|
      raise "+#{ivar}+ should be defined in before block" unless instance_variable_defined?(ivar)
      raise "+#{ivar}+ should not be nil in before block" unless instance_variable_get(ivar)
    end

    @articles.loaded?.should == loaded
  end

  before :all do
    @no_join = defined?(DataMapper::Adapters::InMemoryAdapter) && @adapter.kind_of?(DataMapper::Adapters::InMemoryAdapter) ||
               defined?(DataMapper::Adapters::YamlAdapter)     && @adapter.kind_of?(DataMapper::Adapters::YamlAdapter)

    @many_to_many = @articles.kind_of?(DataMapper::Associations::ManyToMany::Collection)

    @skip = @no_join && @many_to_many
  end

  before do
    pending if @skip
  end

  [ :[], :slice ].each do |method|
    it { @articles.should respond_to(method) }

    describe "##{method}" do
      before :all do
        1.upto(10) { |number| @articles.create(:content => "Article #{number}") }
        @copy = @articles.dup
      end

      describe 'with a positive offset' do
        before :all do
          unless @skip
            @return = @resource = @articles.send(method, 0)
          end
        end

        it 'should return a Resource' do
          @return.should be_kind_of(DataMapper::Resource)
        end

        it 'should return expected Resource' do
          @return.should == @copy.entries.send(method, 0)
        end

        it 'should not remove the Resource from the Collection' do
          @articles.should be_include(@resource)
        end

        it 'should relate the Resource to the Collection' do
          @resource.collection.should equal(@articles)
        end
      end

      describe 'with a positive offset and length' do
        before :all do
          @return = @resources = @articles.send(method, 5, 5)
        end

        it 'should return a Collection' do
          @return.should be_kind_of(DataMapper::Collection)
        end

        it 'should return the expected Resource' do
          @return.should == @copy.entries.send(method, 5, 5)
        end

        it 'should not remove the Resources from the Collection' do
          @resources.each { |resource| @articles.should be_include(resource) }
        end

        it 'should orphan the Resources' do
          @resources.each { |resource| resource.collection.should_not equal(@articles) }
        end

        it 'should scope the Collection' do
          @resources.reload.should == @copy.entries.send(method, 5, 5)
        end
      end

      describe 'with a positive range' do
        before :all do
          @return = @resources = @articles.send(method, 5..10)
        end

        it 'should return a Collection' do
          @return.should be_kind_of(DataMapper::Collection)
        end

        it 'should return the expected Resources' do
          @return.should == @copy.entries.send(method, 5..10)
        end

        it 'should not remove the Resources from the Collection' do
          @resources.each { |resource| @articles.should be_include(resource) }
        end

        it 'should orphan the Resources' do
          @resources.each { |resource| resource.collection.should_not equal(@articles) }
        end

        it 'should scope the Collection' do
          @resources.reload.should == @copy.entries.send(method, 5..10)
        end
      end

      describe 'with a negative offset' do
        before :all do
          unless @skip
            @return = @resource = @articles.send(method, -1)
          end
        end

        it 'should return a Resource' do
          @return.should be_kind_of(DataMapper::Resource)
        end

        it 'should return expected Resource' do
          @return.should == @copy.entries.send(method, -1)
        end

        it 'should not remove the Resource from the Collection' do
          @articles.should be_include(@resource)
        end

        it 'should relate the Resource to the Collection' do
          @resource.collection.should equal(@articles)
        end
      end

      describe 'with a negative offset and length' do
        before :all do
          @return = @resources = @articles.send(method, -5, 5)
        end

        it 'should return a Collection' do
          @return.should be_kind_of(DataMapper::Collection)
        end

        it 'should return the expected Resources' do
          @return.should == @copy.entries.send(method, -5, 5)
        end

        it 'should not remove the Resources from the Collection' do
          @resources.each { |resource| @articles.should be_include(resource) }
        end

        it 'should orphan the Resources' do
          @resources.each { |resource| resource.collection.should_not equal(@articles) }
        end

        it 'should scope the Collection' do
          @resources.reload.should == @copy.entries.send(method, -5, 5)
        end
      end

      describe 'with a negative range' do
        before :all do
          @return = @resources = @articles.send(method, -5..-2)
        end

        it 'should return a Collection' do
          @return.should be_kind_of(DataMapper::Collection)
        end

        it 'should return the expected Resources' do
          @return.to_a.should == @copy.entries.send(method, -5..-2)
        end

        it 'should not remove the Resources from the Collection' do
          @resources.each { |resource| @articles.should be_include(resource) }
        end

        it 'should orphan the Resources' do
          @resources.each { |resource| resource.collection.should_not equal(@articles) }
        end

        it 'should scope the Collection' do
          @resources.reload.should == @copy.entries.send(method, -5..-2)
        end
      end

      describe 'with an empty exclusive range' do
        before :all do
          @return = @resources = @articles.send(method, 0...0)
        end

        it 'should return a Collection' do
          @return.should be_kind_of(DataMapper::Collection)
        end

        it 'should return the expected value' do
          @return.to_a.should == @copy.entries.send(method, 0...0)
        end

        it 'should be empty' do
          @return.should be_empty
        end
      end

      describe 'with an offset not within the Collection' do
        before :all do
          unless @skip
            @return = @articles.send(method, 12)
          end
        end

        it 'should return nil' do
          @return.should be_nil
        end
      end

      describe 'with an offset and length not within the Collection' do
        before :all do
          @return = @articles.send(method, 12, 1)
        end

        it 'should return a Collection' do
          @return.should be_kind_of(DataMapper::Collection)
        end

        it 'should be empty' do
          @return.should be_empty
        end
      end

      describe 'with a range not within the Collection' do
        before :all do
          @return = @articles.send(method, 12..13)
        end

        it 'should return a Collection' do
          @return.should be_kind_of(DataMapper::Collection)
        end

        it 'should be empty' do
          @return.should be_empty
        end
      end
    end
  end

  it { @articles.should respond_to(:all) }

  describe '#all' do
    describe 'with no arguments' do
      before :all do
        @copy = @articles.dup

        @return = @collection = @articles.all
      end

      it 'should return a Collection' do
        @return.should be_kind_of(DataMapper::Collection)
      end

      it 'should return self' do
        @return.should equal(@articles)
      end

      it 'should be expected Resources' do
        @collection.should == [ @article ]
      end

      it 'should have the same query as original Collection' do
        @collection.query.should equal(@articles.query)
      end

      it 'should scope the Collection' do
        @collection.reload.should == @copy.entries
      end
    end

    describe 'with a query' do
      before :all do
        @new  = @articles.create(:content => 'New Article')
        @copy = @articles.dup

        # search for the first 10 articles, then take the first 5, and then finally take the
        # second article from the remainder
        @return = @articles.all(:limit => 10).all(:limit => 5).all(:limit => 1, :offset => 1)
      end

      it 'should return a Collection' do
        @return.should be_kind_of(DataMapper::Collection)
      end

      it 'should be a new Collection' do
        @return.should_not equal(@articles)
      end

      it 'should be expected Resources' do
        @return.size.should == 1
        @return.first.should equal(@new)
      end

      it 'should have a different query than original Collection' do
        @return.query.should_not == @articles.query
      end

      it 'should scope the Collection' do
        @return.reload.should == @copy.entries.first(10).first(5)[1, 1]
      end
    end

    describe 'with a query using raw conditions' do
      before do
        pending unless defined?(DataMapper::Adapters::DataObjectsAdapter) && @adapter.kind_of?(DataMapper::Adapters::DataObjectsAdapter)
      end

      before :all do
        @new = @articles.create(:content => 'New Article')
        @copy = @articles.dup

        @return = @articles.all(:conditions => [ 'content = ?', 'New Article' ])
      end

      it 'should return a Collection' do
        @return.should be_kind_of(DataMapper::Collection)
      end

      it 'should be a new Collection' do
        @return.should_not equal(@articles)
      end

      it 'should be expected Resources' do
        @return.should == [ @new ]
      end

      it 'should have a different query than original Collection' do
        @return.query.should_not == @articles.query
      end

      it 'should scope the Collection' do
        @return.reload.should == @copy.entries.select { |resource| resource.content == 'New Article' }.first(1)
      end
    end

    describe 'with a query that is out of range' do
      it 'should raise an exception' do
        lambda {
          @articles.all(:limit => 10).all(:offset => 10)
        }.should raise_error(RangeError, 'offset 10 and limit 0 are outside allowed range')
      end
    end
  end

  it { @articles.should respond_to(:at) }

  describe '#at' do
    describe 'with positive offset' do
      before :all do
        @return = @resource = @articles.at(0)
      end

      should_not_be_a_kicker

      it 'should return a Resource' do
        @return.should be_kind_of(DataMapper::Resource)
      end

      it 'should return expected Resource' do
        @resource.should == @article
      end

      it "should #{'not' unless loaded} relate the Resource to the Collection" do
        @resource.collection.equal?(@articles).should == loaded
      end
    end

    describe 'with positive offset', 'after prepending to the collection' do
      before :all do
        @return = @resource = @articles.unshift(@other).at(0)
      end

      should_not_be_a_kicker

      it 'should return a Resource' do
        @return.should be_kind_of(DataMapper::Resource)
      end

      it 'should return expected Resource' do
        @resource.should equal(@other)
      end

      it 'should relate the Resource to the Collection' do
        @resource.collection.should equal(@articles)
      end
    end

    describe 'with negative offset' do
      before :all do
        @return = @resource = @articles.at(-1)
      end

      should_not_be_a_kicker

      it 'should return a Resource' do
        @return.should be_kind_of(DataMapper::Resource)
      end

      it 'should return expected Resource' do
        @resource.should == @article
      end

      it "should #{'not' unless loaded} relate the Resource to the Collection" do
        @resource.collection.equal?(@articles).should == loaded
      end
    end

    describe 'with negative offset', 'after appending to the collection' do
      before :all do
        @return = @resource = @articles.push(@other).at(-1)
      end

      should_not_be_a_kicker

      it 'should return a Resource' do
        @return.should be_kind_of(DataMapper::Resource)
      end

      it 'should return expected Resource' do
        @resource.should equal(@other)
      end

      it 'should relate the Resource to the Collection' do
        @resource.collection.should equal(@articles)
      end
    end
  end

  it { @articles.should respond_to(:first) }

  describe '#first' do
    before :all do
      @copy = @articles.dup
      @copy.to_a
    end

    describe 'with no arguments' do
      before :all do
        @return = @resource = @articles.first
      end

      it 'should return a Resource' do
        @return.should be_kind_of(DataMapper::Resource)
      end

      it 'should return expected Resource' do
        @resource.should == @article
      end

      it 'should be first Resource in the Collection' do
        @resource.should == @copy.entries.first
      end

      it 'should not relate the Resource to the Collection' do
        @resource.collection.should_not equal(@articles)
      end
    end

    describe 'with no arguments', 'after prepending to the collection' do
      before :all do
        @return = @resource = @articles.unshift(@other).first
      end

      it 'should return a Resource' do
        @return.should be_kind_of(DataMapper::Resource)
      end

      it 'should return expected Resource' do
        @resource.should equal(@other)
      end

      it 'should be first Resource in the Collection' do
        @resource.should equal(@copy.entries.unshift(@other).first)
      end

      it 'should not relate the Resource to the Collection' do
        @resource.collection.should_not equal(@articles)
      end
    end

    describe 'with empty query' do
      before :all do
        @return = @resource = @articles.first({})
      end

      it 'should return a Resource' do
        @return.should be_kind_of(DataMapper::Resource)
      end

      it 'should return expected Resource' do
        @resource.should == @article
      end

      it 'should be first Resource in the Collection' do
        @resource.should == @copy.entries.first
      end

      it 'should not relate the Resource to the Collection' do
        @resource.collection.should_not equal(@articles)
      end
    end

    describe 'with empty query', 'after prepending to the collection' do
      before :all do
        @return = @resource = @articles.unshift(@other).first({})
      end

      it 'should return a Resource' do
        @return.should be_kind_of(DataMapper::Resource)
      end

      it 'should return expected Resource' do
        @resource.should equal(@other)
      end

      it 'should be first Resource in the Collection' do
        @resource.should equal(@copy.entries.unshift(@other).first)
      end

      it 'should not relate the Resource to the Collection' do
        @resource.collection.should_not equal(@articles)
      end
    end

    describe 'with a query' do
      before :all do
        @return = @resource = @articles.first(:content => 'Sample')
      end

      it 'should return a Resource' do
        @return.should be_kind_of(DataMapper::Resource)
      end

      it 'should should be the first Resource in the Collection matching the query' do
        @resource.should == @article
      end

      it 'should not relate the Resource to the Collection' do
        @resource.collection.should_not equal(@articles)
      end
    end

    describe 'with limit specified' do
      before :all do
        @return = @resources = @articles.first(1)
      end

      it 'should return a Collection' do
        @return.should be_kind_of(DataMapper::Collection)
      end

      it 'should be the expected Collection' do
        @resources.should == [ @article ]
      end

      it 'should be the first N Resources in the Collection' do
        @resources.should == @copy.entries.first(1)
      end

      it 'should orphan the Resources' do
        @resources.each { |resource| resource.collection.should_not equal(@articles) }
      end
    end

    describe 'with limit specified', 'after prepending to the collection' do
      before :all do
        @return = @resources = @articles.unshift(@other).first(1)
      end

      it 'should return a Collection' do
        @return.should be_kind_of(DataMapper::Collection)
      end

      it 'should be the expected Collection' do
        @resources.should == [ @other ]
      end

      it 'should be the first N Resources in the Collection' do
        @resources.should == @copy.entries.unshift(@other).first(1)
      end

      it 'should orphan the Resources' do
        @resources.each { |resource| resource.collection.should_not equal(@articles) }
      end
    end

    describe 'with limit and query specified' do
      before :all do
        @return = @resources = @articles.first(1, :content => 'Sample')
      end

      it 'should return a Collection' do
        @return.should be_kind_of(DataMapper::Collection)
      end

      it 'should be the first N Resources in the Collection matching the query' do
        @resources.should == [ @article ]
      end

      it 'should orphan the Resources' do
        @resources.each { |resource| resource.collection.should_not equal(@articles) }
      end
    end
  end

  it { @articles.should respond_to(:first_or_create) }

  describe '#first_or_create' do
    describe 'with conditions that find an existing Resource' do
      before :all do
        @return = @resource = @articles.first_or_create(@article.attributes)
      end

      it 'should return a Resource' do
        @return.should be_kind_of(DataMapper::Resource)
      end

      it 'should be expected Resource' do
        @resource.should == @article
      end

      it 'should be a saved Resource' do
        @resource.should be_saved
      end

      it 'should not relate the Resource to the Collection' do
        @resource.collection.should_not equal(@articles)
      end
    end

    describe 'with conditions that do not find an existing Resource' do
      before :all do
        @conditions = { :content => 'Unknown Content' }
        @attributes = {}

        @return = @resource = @articles.first_or_create(@conditions, @attributes)
      end

      it 'should return a Resource' do
        @return.should be_kind_of(DataMapper::Resource)
      end

      it 'should be expected Resource' do
        @resource.attributes.only(:title, :content).should == { :title => 'Sample Article', :content => 'Unknown Content' }
      end

      it 'should be a saved Resource' do
        @resource.should be_saved
      end

      it 'should relate the Resource to the Collection' do
        @resource.collection.should equal(@articles)
      end
    end
  end

  it { @articles.should respond_to(:first_or_new) }

  describe '#first_or_new' do
    describe 'with conditions that find an existing Resource' do
      before :all do
        @return = @resource = @articles.first_or_new(@article.attributes)
      end

      it 'should return a Resource' do
        @return.should be_kind_of(DataMapper::Resource)
      end

      it 'should be expected Resource' do
        @resource.should == @article
      end

      it 'should be a saved Resource' do
        @resource.should be_saved
      end

      it 'should not relate the Resource to the Collection' do
        @resource.collection.should_not equal(@articles)
      end
    end

    describe 'with conditions that do not find an existing Resource' do
      before :all do
        @conditions = { :content => 'Unknown Content' }
        @attributes = {}

        @return = @resource = @articles.first_or_new(@conditions, @attributes)
      end

      it 'should return a Resource' do
        @return.should be_kind_of(DataMapper::Resource)
      end

      it 'should be expected Resource' do
        @resource.attributes.only(:title, :content).should == { :title => 'Sample Article', :content => 'Unknown Content' }
      end

      it 'should not be a saved Resource' do
        @resource.should be_new
      end

      it 'should relate the Resource to the Collection' do
        @resource.collection.should equal(@articles)
      end
    end
  end

  it { @articles.should respond_to(:get) }

  describe '#get' do
    describe 'with a key to a Resource within the Collection' do
      before :all do
        @return = @resource = @articles.get(*@article.key)
      end

      it 'should return a Resource' do
        @return.should be_kind_of(DataMapper::Resource)
      end

      it 'should be matching Resource in the Collection' do
        @resource.should == @article
      end
    end

    describe 'with a key to a Resource not within the Collection' do
      before :all do
        @return = @articles.get(*@other.key)
      end

      it 'should return nil' do
        @return.should be_nil
      end
    end

    describe 'with a key not typecast' do
      before :all do
        @return = @resource = @articles.get(*@article.key.map { |value| value.to_s })
      end

      it 'should return a Resource' do
        @return.should be_kind_of(DataMapper::Resource)
      end

      it 'should be matching Resource in the Collection' do
        @resource.should == @article
      end
    end

    describe 'with a key to a Resource within a Collection using a limit' do
      before :all do
        @articles = @articles.all(:limit => 1)

        @return = @resource = @articles.get(*@article.key)
      end

      it 'should return a Resource' do
        @return.should be_kind_of(DataMapper::Resource)
      end

      it 'should be matching Resource in the Collection' do
        @resource.should == @article
      end
    end

    describe 'with a key to a Resource within a Collection using an offset' do
      before :all do
        @new = @articles.create(:content => 'New Article')  # TODO: freeze @new
        @articles = @articles.all(:offset => 1, :limit => 1)

        @return = @resource = @articles.get(*@new.key)
      end

      it 'should return a Resource' do
        @return.should be_kind_of(DataMapper::Resource)
      end

      it 'should be matching Resource in the Collection' do
        @resource.should equal(@new)
      end
    end

    describe 'with a key that is nil' do
      before :all do
        @return = @resource = @articles.get(nil)
      end

      it 'should return nil' do
        @return.should be_nil
      end
    end

    describe 'with a key that is an empty String' do
      before :all do
        @return = @resource = @articles.get('')
      end

      it 'should return nil' do
        @return.should be_nil
      end
    end
  end

  it { @articles.should respond_to(:get!) }

  describe '#get!' do
    describe 'with a key to a Resource within the Collection' do
      before :all do
        unless @skip
          @return = @resource = @articles.get!(*@article.key)
        end
      end

      it 'should return a Resource' do
        @return.should be_kind_of(DataMapper::Resource)
      end

      it 'should be matching Resource in the Collection' do
        @resource.should == @article
      end
    end

    describe 'with a key to a Resource not within the Collection' do
      it 'should raise an exception' do
        lambda {
          @articles.get!(99)
        }.should raise_error(DataMapper::ObjectNotFoundError, "Could not find #{@article_model} with key [99] in collection")
      end
    end

    describe 'with a key not typecast' do
      before :all do
        unless @skip
          @return = @resource = @articles.get!(*@article.key.map { |value| value.to_s })
        end
      end

      it 'should return a Resource' do
        @return.should be_kind_of(DataMapper::Resource)
      end

      it 'should be matching Resource in the Collection' do
        @resource.should == @article
      end
    end

    describe 'with a key to a Resource within a Collection using a limit' do
      before :all do
        unless @skip
          @articles = @articles.all(:limit => 1)

          @return = @resource = @articles.get!(*@article.key)
        end
      end

      it 'should return a Resource' do
        @return.should be_kind_of(DataMapper::Resource)
      end

      it 'should be matching Resource in the Collection' do
        @resource.should == @article
      end
    end

    describe 'with a key to a Resource within a Collection using an offset' do
      before :all do
        unless @skip
          @new = @articles.create(:content => 'New Article')  # TODO: freeze @new
          @articles = @articles.all(:offset => 1, :limit => 1)

          @return = @resource = @articles.get!(*@new.key)
        end
      end

      it 'should return a Resource' do
        @return.should be_kind_of(DataMapper::Resource)
      end

      it 'should be matching Resource in the Collection' do
        @resource.should equal(@new)
      end
    end

    describe 'with a key that is nil' do
      before :all do
        @key = nil
      end

      it 'should raise an exception' do
        lambda {
          @articles.get!(@key)
        }.should raise_error(DataMapper::ObjectNotFoundError, "Could not find #{@article_model} with key [#{@key.inspect}] in collection")
      end
    end

    describe 'with a key that is an empty String' do
      before :all do
        @key = ''
      end

      it 'should raise an exception' do
        lambda {
          @articles.get!(@key)
        }.should raise_error(DataMapper::ObjectNotFoundError, "Could not find #{@article_model} with key [#{@key.inspect}] in collection")
      end
    end
  end

  it { @articles.should respond_to(:last) }

  describe '#last' do
    before :all do
      @copy = @articles.dup
      @copy.to_a
    end

    describe 'with no arguments' do
      before :all do
        @return = @resource = @articles.last
      end

      it 'should return a Resource' do
        @return.should be_kind_of(DataMapper::Resource)
      end

      it 'should return expected Resource' do
        @resource.should == @article
      end

      it 'should be last Resource in the Collection' do
        @resource.should == @copy.entries.last
      end

      it 'should not relate the Resource to the Collection' do
        @resource.collection.should_not equal(@articles)
      end
    end

    describe 'with no arguments', 'after appending to the collection' do
      before :all do
        @return = @resource = @articles.push(@other).last
      end

      it 'should return a Resource' do
        @return.should be_kind_of(DataMapper::Resource)
      end

      it 'should return expected Resource' do
        @resource.should equal(@other)
      end

      it 'should be last Resource in the Collection' do
        @resource.should equal(@copy.entries.push(@other).last)
      end

      it 'should not relate the Resource to the Collection' do
        @resource.collection.should_not equal(@articles)
      end
    end

    describe 'with a query' do
      before :all do
        @return = @resource = @articles.last(:content => 'Sample')
      end

      it 'should return a Resource' do
        @return.should be_kind_of(DataMapper::Resource)
      end

      it 'should should be the last Resource in the Collection matching the query' do
        @resource.should == @article
      end

      it 'should not relate the Resource to the Collection' do
        @resource.collection.should_not equal(@articles)
      end
    end

    describe 'with limit specified' do
      before :all do
        @return = @resources = @articles.last(1)
      end

      it 'should return a Collection' do
        @return.should be_kind_of(DataMapper::Collection)
      end

      it 'should be the expected Collection' do
        @resources.should == [ @article ]
      end

      it 'should be the last N Resources in the Collection' do
        @resources.should == @copy.entries.last(1)
      end

      it 'should orphan the Resources' do
        @resources.each { |resource| resource.collection.should_not equal(@articles) }
      end
    end

    describe 'with limit specified', 'after appending to the collection' do
      before :all do
        @return = @resources = @articles.push(@other).last(1)
      end

      it 'should return a Collection' do
        @return.should be_kind_of(DataMapper::Collection)
      end

      it 'should be the expected Collection' do
        @resources.should == [ @other ]
      end

      it 'should be the last N Resources in the Collection' do
        @resources.should == @copy.entries.push(@other).last(1)
      end

      it 'should orphan the Resources' do
        @resources.each { |resource| resource.collection.should_not equal(@articles) }
      end
    end

    describe 'with limit and query specified' do
      before :all do
        @return = @resources = @articles.last(1, :content => 'Sample')
      end

      it 'should return a Collection' do
        @return.should be_kind_of(DataMapper::Collection)
      end

      it 'should be the last N Resources in the Collection matching the query' do
        @resources.should == [ @article ]
      end

      it 'should orphan the Resources' do
        @resources.each { |resource| resource.collection.should_not equal(@articles) }
      end
    end
  end

  it { @articles.should respond_to(:reverse) }

  describe '#reverse' do
    before :all do
      @query = @articles.query

      @new = @articles.create(:title => 'Sample Article')

      @return = @articles.reverse
    end

    it 'should return a Collection' do
      @return.should be_kind_of(DataMapper::Collection)
    end

    it 'should return a Collection with reversed entries' do
      @return.should == [ @new, @article ]
    end

    it 'should return a Query that is the reverse of the original' do
      @return.query.should == @query.reverse
    end
  end
end
