share_examples_for 'Finder Interface' do
  before :all do
    %w[ @article_model @article @other @articles ].each do |ivar|
      raise "+#{ivar}+ should be defined in before block" unless instance_variable_defined?(ivar)
      raise "+#{ivar}+ should not be nil in before block" unless instance_variable_get(ivar)
    end
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
        @copy = @articles.kind_of?(Class) ? @articles : @articles.dup
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

        it 'should orphan the Resource' do
          @resource.collection.should_not equal(@articles)
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

        it 'should orphan the Resource' do
          @resource.collection.should_not equal(@articles)
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
            @return = @articles.send(method, 99)
          end
        end

        it 'should return nil' do
          @return.should be_nil
        end
      end

      describe 'with an offset and length not within the Collection' do
        before :all do
          @return = @articles.send(method, 99, 1)
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
          @return = @articles.send(method, 99..100)
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
        @copy = @articles.kind_of?(Class) ? @articles : @articles.dup

        @return = @collection = @articles.all
      end

      it 'should return a Collection' do
        @return.should be_kind_of(DataMapper::Collection)
      end

      it 'should return a new instance' do
        @return.should_not equal(@articles)
      end

      it 'should be expected Resources' do
        @collection.should == @articles.entries
      end

      it 'should not have a Query the same as the original' do
        @return.query.should_not equal(@articles.query)
      end

      it 'should have a Query equal to the original' do
        @return.query.should eql(@articles.query)
      end

      it 'should scope the Collection' do
        @collection.reload.should == @copy.entries
      end
    end

    describe 'with a query' do
      before :all do
        @new  = @articles.create(:content => 'New Article')
        @copy = @articles.kind_of?(Class) ? @articles : @articles.dup

        @return = @articles.all(:content => [ 'New Article' ])
      end

      it 'should return a Collection' do
        @return.should be_kind_of(DataMapper::Collection)
      end

      it 'should return a new instance' do
        @return.should_not equal(@articles)
      end

      it 'should be expected Resources' do
        @return.should == [ @new ]
      end

      it 'should have a different query than original Collection' do
        @return.query.should_not equal(@articles.query)
      end

      it 'should scope the Collection' do
        @return.reload.should == @copy.entries.select { |resource| resource.content == 'New Article' }
      end
    end

    describe 'with a query using raw conditions' do
      before do
        pending unless defined?(DataMapper::Adapters::DataObjectsAdapter) && @adapter.kind_of?(DataMapper::Adapters::DataObjectsAdapter)
      end

      before :all do
        @new  = @articles.create(:subtitle => 'New Article')
        @copy = @articles.kind_of?(Class) ? @articles : @articles.dup

        @return = @articles.all(:conditions => [ 'subtitle = ?', 'New Article' ])
      end

      it 'should return a Collection' do
        @return.should be_kind_of(DataMapper::Collection)
      end

      it 'should return a new instance' do
        @return.should_not equal(@articles)
      end

      it 'should be expected Resources' do
        @return.should == [ @new ]
      end

      it 'should have a different query than original Collection' do
        @return.query.should_not == @articles.query
      end

      it 'should scope the Collection' do
        @return.reload.should == @copy.entries.select { |resource| resource.subtitle == 'New Article' }.first(1)
      end
    end

    describe 'with a query that is out of range' do
      it 'should raise an exception' do
        lambda {
          @articles.all(:limit => 10).all(:offset => 10)
        }.should raise_error(RangeError, 'offset 10 and limit 0 are outside allowed range')
      end
    end

    describe 'with a query using a m:1 relationship' do
      describe 'with a resource' do
        before :all do
          @return = @articles.all(:original => @original)
        end

        it 'should return a Collection' do
          @return.should be_kind_of(DataMapper::Collection)
        end

        it 'should be expected Resources' do
          @return.should == [ @article ]
        end

        it 'should have a valid query' do
          @return.query.should be_valid
        end
      end

      describe 'with a collection' do
        before :all do
          @collection = @article_model.all(@article_model.key.zip(@original.key).to_hash)

          @return = @articles.all(:original => @collection)
        end

        it 'should return a Collection' do
          @return.should be_kind_of(DataMapper::Collection)
        end

        it 'should be expected Resources' do
          @return.should == [ @article ]
        end

        it 'should have a valid query' do
          @return.query.should be_valid
        end

      end

      describe 'with an empty Array' do
        before :all do
          @return = @articles.all(:original => [])
        end

        it 'should return a Collection' do
          @return.should be_kind_of(DataMapper::Collection)
        end

        it 'should be an empty Collection' do
          @return.should be_empty
        end

        it 'should not have a valid query' do
          @return.query.should_not be_valid
        end
      end

      describe 'with a nil value' do
        before :all do
          @return = @articles.all(:original => nil)
        end

        it 'should return a Collection' do
          @return.should be_kind_of(DataMapper::Collection)
        end

        if respond_to?(:model?) && model?
          it 'should be expected Resources' do
            @return.should == [ @original, @other ]
          end
        else
          it 'should be an empty Collection' do
            @return.should be_empty
          end
        end

        it 'should have a valid query' do
          @return.query.should be_valid
        end
      end
    end

    describe 'with a query using a 1:1 relationship' do
      before :all do
        @new = @articles.create(:content => 'New Article', :original => @article)
      end

      describe 'with a resource' do
        before :all do
          @return = @articles.all(:previous => @new)
        end

        it 'should return a Collection' do
          @return.should be_kind_of(DataMapper::Collection)
        end

        it 'should be expected Resources' do
          @return.should == [ @article ]
        end

        it 'should have a valid query' do
          @return.query.should be_valid
        end
      end

      describe 'with a collection' do
        before :all do
          @collection = @article_model.all(@article_model.key.zip(@new.key).to_hash)

          @return = @articles.all(:previous => @collection)
        end

        it 'should return a Collection' do
          @return.should be_kind_of(DataMapper::Collection)
        end

        it 'should be expected Resources' do
          @return.should == [ @article ]
        end

        it 'should have a valid query' do
          @return.query.should be_valid
        end
      end

      describe 'with an empty Array' do
        before :all do
          @return = @articles.all(:previous => [])
        end

        it 'should return a Collection' do
          @return.should be_kind_of(DataMapper::Collection)
        end

        it 'should be an empty Collection' do
          @return.should be_empty
        end

        it 'should not have a valid query' do
          @return.query.should_not be_valid
        end
      end

      describe 'with a nil value' do
        before :all do
          @return = @articles.all(:previous => nil)
        end

        it 'should return a Collection' do
          @return.should be_kind_of(DataMapper::Collection)
        end

        it 'should be an empty Collection' do
          @return.should be_empty
        end

        it 'should have a valid query' do
          @return.query.should be_valid
        end
      end
    end

    describe 'with a query using a 1:m relationship' do
      before :all do
        @new = @articles.create(:content => 'New Article', :original => @article)
      end

      describe 'with a resource' do
        before :all do
          @return = @articles.all(:revisions => @new)
        end

        it 'should return a Collection' do
          @return.should be_kind_of(DataMapper::Collection)
        end

        it 'should be expected Resources' do
          @return.should == [ @article ]
        end

        it 'should have a valid query' do
          @return.query.should be_valid
        end
      end

      describe 'with a collection' do
        before :all do
          @collection = @article_model.all(@article_model.key.zip(@new.key).to_hash)

          @return = @articles.all(:revisions => @collection)
        end

        it 'should return a Collection' do
          @return.should be_kind_of(DataMapper::Collection)
        end

        it 'should be expected Resources' do
          @return.should == [ @article ]
        end

        it 'should have a valid query' do
          @return.query.should be_valid
        end
      end

      describe 'with an empty Array' do
        before :all do
          @return = @articles.all(:revisions => [])
        end

        it 'should return a Collection' do
          @return.should be_kind_of(DataMapper::Collection)
        end

        it 'should be an empty Collection' do
          @return.should be_empty
        end

        it 'should not have a valid query' do
          @return.query.should_not be_valid
        end
      end

      describe 'with a nil value' do
        before :all do
          @return = @articles.all(:revisions => nil)
        end

        it 'should return a Collection' do
          @return.should be_kind_of(DataMapper::Collection)
        end

        it 'should be an empty Collection' do
          @return.should be_empty
        end

        it 'should have a valid query' do
          @return.query.should be_valid
        end
      end
    end

    describe 'with a query using a m:m relationship' do
      before :all do
        @publication = @article.publications.create(:name => 'DataMapper Now')
      end

      describe 'with a resource' do
        before :all do
          @return = @articles.all(:publications => @publication)
        end

        it 'should return a Collection' do
          @return.should be_kind_of(DataMapper::Collection)
        end

        it 'should be expected Resources' do
          pending 'TODO' do
            @return.should == [ @article ]
          end
        end

        it 'should have a valid query' do
          @return.query.should be_valid
        end
      end

      describe 'with a collection' do
        before :all do
          @collection = @publication_model.all(@publication_model.key.zip(@publication.key).to_hash)

          @return = @articles.all(:publications => @collection)
        end

        it 'should return a Collection' do
          @return.should be_kind_of(DataMapper::Collection)
        end

        it 'should be expected Resources' do
          pending 'TODO' do
            @return.should == [ @article ]
          end
        end

        it 'should have a valid query' do
          @return.query.should be_valid
        end
      end

      describe 'with an empty Array' do
        before :all do
          @return = @articles.all(:publications => [])
        end

        it 'should return a Collection' do
          @return.should be_kind_of(DataMapper::Collection)
        end

        it 'should be an empty Collection' do
          @return.should be_empty
        end

        it 'should not have a valid query' do
          @return.query.should_not be_valid
        end
      end

      describe 'with a nil value' do
        before :all do
          @return = @articles.all(:publications => nil)
        end

        it 'should return a Collection' do
          @return.should be_kind_of(DataMapper::Collection)
        end

        it 'should be an empty Collection' do
          @return.should be_empty
        end

        it 'should have a valid query' do
          @return.query.should be_valid
        end
      end
    end
  end

  it { @articles.should respond_to(:at) }

  describe '#at' do
    before :all do
      @copy = @articles.kind_of?(Class) ? @articles : @articles.dup
      @copy.to_a
    end

    describe 'with positive offset' do
      before :all do
        @return = @resource = @articles.at(0)
      end

      should_not_be_a_kicker

      it 'should return a Resource' do
        @return.should be_kind_of(DataMapper::Resource)
      end

      it 'should return expected Resource' do
        @resource.should == @copy.entries.at(0)
      end

      it 'should orphan the Resource' do
        @resource.collection.should_not equal(@articles)
      end
    end

    # describe 'with positive offset', 'after prepending to the collection' do
    #   before :all do
    #     @return = @resource = @articles.unshift(@other).at(0)
    #   end
    #
    #   should_not_be_a_kicker
    #
    #   it 'should return a Resource' do
    #     @return.should be_kind_of(DataMapper::Resource)
    #   end
    #
    #   it 'should return expected Resource' do
    #     @resource.should equal(@other)
    #   end
    #
    #   it 'should relate the Resource to the Collection' do
    #     @resource.collection.should equal(@articles)
    #   end
    # end

    describe 'with negative offset' do
      before :all do
        @return = @resource = @articles.at(-1)
      end

      should_not_be_a_kicker

      it 'should return a Resource' do
        @return.should be_kind_of(DataMapper::Resource)
      end

      it 'should return expected Resource' do
        @resource.should == @copy.entries.at(-1)
      end

      it 'should orphan the Resource' do
        @resource.collection.should_not equal(@articles)
      end
    end

    # describe 'with negative offset', 'after appending to the collection' do
    #   before :all do
    #     @return = @resource = @articles.push(@other).at(-1)
    #   end
    #
    #   should_not_be_a_kicker
    #
    #   it 'should return a Resource' do
    #     @return.should be_kind_of(DataMapper::Resource)
    #   end
    #
    #   it 'should return expected Resource' do
    #     @resource.should equal(@other)
    #   end
    #
    #   it 'should relate the Resource to the Collection' do
    #     @resource.collection.should equal(@articles)
    #   end
    # end
  end

  it { @articles.should respond_to(:first) }

  describe '#first' do
    before :all do
      1.upto(5) { |number| @articles.create(:content => "Article #{number}") }

      @copy = @articles.kind_of?(Class) ? @articles : @articles.dup
      @copy.to_a
    end

    describe 'with no arguments' do
      before :all do
        @return = @resource = @articles.first
      end

      it 'should return a Resource' do
        @return.should be_kind_of(DataMapper::Resource)
      end

      it 'should be first Resource in the Collection' do
        @resource.should == @copy.entries.first
      end

      it 'should orphan the Resource' do
        @resource.collection.should_not equal(@articles)
      end
    end

    # describe 'with no arguments', 'after prepending to the collection' do
    #   before :all do
    #     @return = @resource = @articles.unshift(@other).first
    #   end
    #
    #   it 'should return a Resource' do
    #     @return.should be_kind_of(DataMapper::Resource)
    #   end
    #
    #   it 'should return expected Resource' do
    #     @resource.should equal(@other)
    #   end
    #
    #   it 'should be first Resource in the Collection' do
    #     @resource.should equal(@copy.entries.unshift(@other).first)
    #   end
    #
    #   it 'should not relate the Resource to the Collection' do
    #     @resource.collection.should_not equal(@articles)
    #   end
    # end

    describe 'with empty query' do
      before :all do
        @return = @resource = @articles.first({})
      end

      it 'should return a Resource' do
        @return.should be_kind_of(DataMapper::Resource)
      end

      it 'should be first Resource in the Collection' do
        @resource.should == @copy.entries.first
      end

      it 'should orphan the Resource' do
        @resource.collection.should_not equal(@articles)
      end
    end

    # describe 'with empty query', 'after prepending to the collection' do
    #   before :all do
    #     @return = @resource = @articles.unshift(@other).first({})
    #   end
    #
    #   it 'should return a Resource' do
    #     @return.should be_kind_of(DataMapper::Resource)
    #   end
    #
    #   it 'should return expected Resource' do
    #     @resource.should equal(@other)
    #   end
    #
    #   it 'should be first Resource in the Collection' do
    #     @resource.should equal(@copy.entries.unshift(@other).first)
    #   end
    #
    #   it 'should not relate the Resource to the Collection' do
    #     @resource.collection.should_not equal(@articles)
    #   end
    # end

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

      it 'should orphan the Resource' do
        @resource.collection.should_not equal(@articles)
      end
    end

    describe 'with a limit specified' do
      before :all do
        @return = @resources = @articles.first(1)
      end

      it 'should return a Collection' do
        @return.should be_kind_of(DataMapper::Collection)
      end

      it 'should be the first N Resources in the Collection' do
        @resources.should == @copy.entries.first(1)
      end

      it 'should orphan the Resources' do
        @resources.each { |resource| resource.collection.should_not equal(@articles) }
      end
    end

    describe 'with offset specified' do
      before :all do
        @return = @resource = @articles.first(:offset => 1)
      end

      it 'should return a Resource' do
        @return.should be_kind_of(DataMapper::Resource)
      end

      it 'should be the second Resource in the Collection' do
        @resource.should == @copy.entries[1]
      end

      it 'should orphan the Resource' do
        @resource.collection.should_not equal(@articles)
      end
    end

    # describe 'with a limit specified', 'after prepending to the collection' do
    #   before :all do
    #     @return = @resources = @articles.unshift(@other).first(1)
    #   end
    #
    #   it 'should return a Collection' do
    #     @return.should be_kind_of(DataMapper::Collection)
    #   end
    #
    #   it 'should be the expected Collection' do
    #     @resources.should == [ @other ]
    #   end
    #
    #   it 'should be the first N Resources in the Collection' do
    #     @resources.should == @copy.entries.unshift(@other).first(1)
    #   end
    #
    #   it 'should orphan the Resources' do
    #     @resources.each { |resource| resource.collection.should_not equal(@articles) }
    #   end
    # end

    describe 'with a limit and query specified' do
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

      it 'should orphan the Resource' do
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
        @resource.attributes.only(*@conditions.keys).should == @conditions
      end

      it 'should be a saved Resource' do
        @resource.should be_saved
      end

      # it 'should relate the Resource' do
      #   @resource.collection.should equal(@articles)
      # end
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

      it 'should orphan the Resource' do
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
        @resource.attributes.only(*@conditions.keys).should == @conditions
      end

      it 'should not be a saved Resource' do
        @resource.should be_new
      end

      # it 'should relate the Resource' do
      #   @resource.collection.should equal(@articles)
      # end
    end
  end

  [ :get, :get! ].each do |method|
    it { @articles.should respond_to(method) }

    describe "##{method}" do
      describe 'with a key to a Resource within the Collection' do
        before :all do
          unless @skip
            @return = @resource = @articles.send(method, *@article.key)
          end
        end

        it 'should return a Resource' do
          @return.should be_kind_of(DataMapper::Resource)
        end

        it 'should be matching Resource in the Collection' do
          @resource.should == @article
        end

        it 'should orphan the Resource' do
          @resource.collection.should_not equal(@articles)
        end
      end

      describe 'with a key not typecast' do
        before :all do
          unless @skip
            @return = @resource = @articles.send(method, *@article.key.map { |value| value.to_s })
          end
        end

        it 'should return a Resource' do
          @return.should be_kind_of(DataMapper::Resource)
        end

        it 'should be matching Resource in the Collection' do
          @resource.should == @article
        end

        it 'should orphan the Resource' do
          @resource.collection.should_not equal(@articles)
        end
      end

      # describe 'with a key to a Resource within a Collection using a limit' do
      #   before :all do
      #     @articles = @articles.all(:limit => 1)
      #
      #     @return = @resource = @articles.send(method, *@article.key)
      #   end
      #
      #   it 'should return a Resource' do
      #     @return.should be_kind_of(DataMapper::Resource)
      #   end
      #
      #   it 'should be matching Resource in the Collection' do
      #     @resource.should == @article
      #   end
      #
      #   it 'should orphan the Resource' do
      #     @resource.collection.should_not equal(@articles)
      #   end
      # end
      #
      # describe 'with a key to a Resource within a Collection using an offset' do
      #   before :all do
      #     @new = @articles.create(:content => 'New Article')  # TODO: freeze @new
      #     @articles = @articles.all(:offset => 1, :limit => 1)
      #
      #     @return = @resource = @articles.send(method, *@new.key)
      #   end
      #
      #   it 'should return a Resource' do
      #     @return.should be_kind_of(DataMapper::Resource)
      #   end
      #
      #   it 'should be matching Resource in the Collection' do
      #     @resource.should equal(@new)
      #   end
      #
      #   it 'should orphan the Resource' do
      #     @resource.collection.should_not equal(@articles)
      #   end
      # end

      describe 'with a key to a Resource not within the Collection' do
        if method == :get
          it 'should return nil' do
            @articles.get(99).should be_nil
          end
        else
          it 'should raise an exception' do
            lambda {
              @articles.get!(99)
            }.should raise_error(DataMapper::ObjectNotFoundError, "Could not find #{@article_model} with key \[99\]")
          end
        end
      end

      describe 'with a key that is nil' do
        if method == :get
          it 'should return nil' do
            @articles.get(nil).should be_nil
          end
        else
          it 'should raise an exception' do
            lambda {
              @articles.get!(nil)
            }.should raise_error(DataMapper::ObjectNotFoundError, "Could not find #{@article_model} with key [nil]")
          end
        end
      end

      describe 'with a key that is an empty String' do
        if method == :get
          it 'should return nil' do
            @articles.get('').should be_nil
          end
        else
          it 'should raise an exception' do
            lambda {
              @articles.get!('')
            }.should raise_error(DataMapper::ObjectNotFoundError, "Could not find #{@article_model} with key [\"\"]")
          end
        end
      end
    end
  end

  it { @articles.should respond_to(:last) }

  describe '#last' do
    before :all do
      1.upto(5) { |number| @articles.create(:content => "Article #{number}") }

      @copy = @articles.kind_of?(Class) ? @articles : @articles.dup
      @copy.to_a
    end

    describe 'with no arguments' do
      before :all do
        @return = @resource = @articles.last
      end

      it 'should return a Resource' do
        @return.should be_kind_of(DataMapper::Resource)
      end

      it 'should be last Resource in the Collection' do
        @resource.should == @copy.entries.last
      end

      # it 'should not relate the Resource to the Collection' do
      #   @resource.collection.should_not equal(@articles)
      # end
    end

    # describe 'with no arguments', 'after appending to the collection' do
    #   before :all do
    #     @return = @resource = @articles.push(@other).last
    #   end
    #
    #   it 'should return a Resource' do
    #     @return.should be_kind_of(DataMapper::Resource)
    #   end
    #
    #   it 'should return expected Resource' do
    #     @resource.should equal(@other)
    #   end
    #
    #   it 'should be last Resource in the Collection' do
    #     @resource.should equal(@copy.entries.push(@other).last)
    #   end
    #
    #   it 'should not relate the Resource to the Collection' do
    #     @resource.collection.should_not equal(@articles)
    #   end
    # end

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

      # it 'should not relate the Resource to the Collection' do
      #   @resource.collection.should_not equal(@articles)
      # end
    end

    describe 'with a limit specified' do
      before :all do
        @return = @resources = @articles.last(1)
      end

      it 'should return a Collection' do
        @return.should be_kind_of(DataMapper::Collection)
      end

      it 'should be the last N Resources in the Collection' do
        @resources.should == @copy.entries.last(1)
      end

      # it 'should orphan the Resources' do
      #   @resources.each { |resource| resource.collection.should_not equal(@articles) }
      # end
    end

    describe 'with offset specified' do
      before :all do
        @return = @resource = @articles.last(:offset => 1)
      end

      it 'should return a Resource' do
        @return.should be_kind_of(DataMapper::Resource)
      end

      it 'should be the second Resource in the Collection' do
        @resource.should == @copy.entries[-2]
      end

      it 'should orphan the Resource' do
        @resource.collection.should_not equal(@articles)
      end
    end

    # describe 'with a limit specified', 'after appending to the collection' do
    #   before :all do
    #     @return = @resources = @articles.push(@other).last(1)
    #   end
    #
    #   it 'should return a Collection' do
    #     @return.should be_kind_of(DataMapper::Collection)
    #   end
    #
    #   it 'should be the expected Collection' do
    #     @resources.should == [ @other ]
    #   end
    #
    #   it 'should be the last N Resources in the Collection' do
    #     @resources.should == @copy.entries.push(@other).last(1)
    #   end
    #
    #  it 'should orphan the Resources' do
    #    @resources.each { |resource| resource.collection.should_not equal(@articles) }
    #   end
    # end

    describe 'with a limit and query specified' do
      before :all do
        @return = @resources = @articles.last(1, :content => 'Sample')
      end

      it 'should return a Collection' do
        @return.should be_kind_of(DataMapper::Collection)
      end

      it 'should be the last N Resources in the Collection matching the query' do
        @resources.should == [ @article ]
      end

      # it 'should orphan the Resources' do
      #   @resources.each { |resource| resource.collection.should_not equal(@articles) }
      # end
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
      @return.should == @articles.entries.reverse
    end

    it 'should return a Query that is the reverse of the original' do
      @return.query.should == @query.reverse
    end
  end

  it 'should respond to a belongs_to relationship method with #method_missing' do
    pending_if 'Model#method_missing should delegate to relationships', @articles.kind_of?(Class) do
      @articles.should respond_to(:original)
    end
  end

  it 'should respond to a has n relationship method with #method_missing' do
    pending_if 'Model#method_missing should delegate to relationships', @articles.kind_of?(Class) do
      @articles.should respond_to(:revisions)
    end
  end

  it 'should respond to a has 1 relationship method with #method_missing' do
    pending_if 'Model#method_missing should delegate to relationships', @articles.kind_of?(Class) do
      @articles.should respond_to(:previous)
    end
  end

  describe '#method_missing' do
    before do
      pending 'Model#method_missing should delegate to relationships' if @articles.kind_of?(Class)
    end

    describe 'with a belongs_to relationship method' do
      before :all do
        rescue_if 'Model#method_missing should delegate to relationships', @articles.kind_of?(Class) do
          @articles.create(:content => 'Another Article', :original => @original)

          @return = @collection = @articles.originals
        end
      end

      # FIXME: this is spec order dependent, move this into a helper method
      # and execute in the before :all block
      unless loaded
        it 'should not be a kicker' do
          pending do
            @articles.should_not be_loaded
          end
        end
      end

      it 'should return a Collection' do
        @return.should be_kind_of(DataMapper::Collection)
      end

      it 'should return expected Collection' do
        @collection.should == [ @original ]
      end

      it 'should set the association for each Resource' do
        @articles.map { |resource| resource.original }.should == [ @original, @original ]
      end
    end

    describe 'with a has 1 relationship method' do
      before :all do
        @new = @articles.new

        @article.previous = @new
        @new.previous     = @other

        @article.save
        @new.save
      end

      describe 'with no arguments' do
        before :all do
          @return = @articles.previous
        end

        # FIXME: this is spec order dependent, move this into a helper method
        # and execute in the before :all block
        unless loaded
          it 'should not be a kicker' do
            pending do
              @articles.should_not be_loaded
            end
          end
        end

        it 'should return a Collection' do
          @return.should be_kind_of(DataMapper::Collection)
        end

        it 'should return expected Collection' do
          # association is sorted reverse by id
          @return.should == [ @new, @other ]
        end

        it 'should set the association for each Resource' do
          @articles.map { |resource| resource.previous }.should == [ @new, @other ]
        end
      end

      describe 'with arguments' do
        before :all do
          @return = @articles.previous(:fields => [ :id ])
        end

        # FIXME: this is spec order dependent, move this into a helper method
        # and execute in the before :all block
        unless loaded
          it 'should not be a kicker' do
            pending do
              @articles.should_not be_loaded
            end
          end
        end

        it 'should return a Collection' do
          @return.should be_kind_of(DataMapper::Collection)
        end

        it 'should return expected Collection' do
          # association is sorted reverse by id
          @return.should == [ @new, @other ]
        end

        { :id => true, :title => false, :content => false }.each do |attribute, expected|
          it "should have query field #{attribute.inspect} #{'not' unless expected} loaded".squeeze(' ') do
            @return.each { |resource| resource.attribute_loaded?(attribute).should == expected }
          end
        end

        it 'should set the association for each Resource' do
          @articles.map { |resource| resource.previous }.should == [ @new, @other ]
        end
      end
    end

    describe 'with a has n relationship method' do
      before :all do
        @new = @articles.new

        # associate the article with children
        @article.revisions << @new
        @new.revisions     << @other

        @article.save
        @new.save
      end

      describe 'with no arguments' do
        before :all do
          @return = @collection = @articles.revisions
        end

        # FIXME: this is spec order dependent, move this into a helper method
        # and execute in the before :all block
        unless loaded
          it 'should not be a kicker' do
            pending do
              @articles.should_not be_loaded
            end
          end
        end

        it 'should return a Collection' do
          @return.should be_kind_of(DataMapper::Collection)
        end

        it 'should return expected Collection' do
          @collection.should == [ @other, @new ]
        end

        it 'should set the association for each Resource' do
          @articles.map { |resource| resource.revisions }.should == [ [ @new ], [ @other ] ]
        end
      end

      describe 'with arguments' do
        before :all do
          @return = @collection = @articles.revisions(:fields => [ :id ])
        end

        # FIXME: this is spec order dependent, move this into a helper method
        # and execute in the before :all block
        unless loaded
          it 'should not be a kicker' do
            pending do
              @articles.should_not be_loaded
            end
          end
        end

        it 'should return a Collection' do
          @return.should be_kind_of(DataMapper::Collection)
        end

        it 'should return expected Collection' do
          @collection.should == [ @other, @new ]
        end

        { :id => true, :title => false, :content => false }.each do |attribute, expected|
          it "should have query field #{attribute.inspect} #{'not' unless expected} loaded".squeeze(' ') do
            @collection.each { |resource| resource.attribute_loaded?(attribute).should == expected }
          end
        end

        it 'should set the association for each Resource' do
          @articles.map { |resource| resource.revisions }.should == [ [ @new ], [ @other ] ]
        end
      end
    end

    describe 'with a has n :through relationship method' do
      before :all do
        @new = @articles.create

        @publication1 = @article.publications.create(:name => 'Ruby Today')
        @publication2 = @new.publications.create(:name => 'Inside DataMapper')
      end

      describe 'with no arguments' do
        before :all do
          @return = @collection = @articles.publications
        end

        # FIXME: this is spec order dependent, move this into a helper method
        # and execute in the before :all block
        unless loaded
          it 'should not be a kicker' do
            pending do
              @articles.should_not be_loaded
            end
          end
        end

        it 'should return a Collection' do
          @return.should be_kind_of(DataMapper::Collection)
        end

        it 'should return expected Collection' do
          pending_if 'TODO', @no_join do
            @collection.should == [ @publication1, @publication2 ]
          end
        end

        it 'should set the association for each Resource' do
          pending_if 'TODO', @no_join do
            @articles.map { |resource| resource.publications }.should == [ [ @publication1 ], [ @publication2 ] ]
          end
        end
      end

      describe 'with arguments' do
        before :all do
          @return = @collection = @articles.publications(:fields => [ :id ])
        end

        # FIXME: this is spec order dependent, move this into a helper method
        # and execute in the before :all block
        unless loaded
          it 'should not be a kicker' do
            pending do
              @articles.should_not be_loaded
            end
          end
        end

        it 'should return a Collection' do
          @return.should be_kind_of(DataMapper::Collection)
        end

        it 'should return expected Collection' do
          pending_if 'TODO', @no_join do
            @collection.should == [ @publication1, @publication2 ]
          end
        end

        { :id => true, :name => false }.each do |attribute, expected|
          it "should have query field #{attribute.inspect} #{'not' unless expected} loaded".squeeze(' ') do
            @collection.each { |resource| resource.attribute_loaded?(attribute).should == expected }
          end
        end

        it 'should set the association for each Resource' do
          pending_if 'TODO', @no_join do
            @articles.map { |resource| resource.publications }.should == [ [ @publication1 ], [ @publication2 ] ]
          end
        end
      end
    end

    describe 'with an unknown method' do
      it 'should raise an exception' do
        lambda {
          @articles.unknown
        }.should raise_error(NoMethodError)
      end
    end
  end
end
