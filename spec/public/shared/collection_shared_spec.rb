module CollectionSharedSpec
  module GroupMethods
    def self.extended(base)
      base.class_inheritable_accessor :loaded
      base.loaded = false
    end
  end
end

share_examples_for 'A Collection' do
  before do
    %w[ @model @article @other @articles @other_articles ].each do |ivar|
      raise "+#{ivar}+ should be defined in before block" unless instance_variable_get(ivar)
    end
  end

  [ :add, :<< ].each do |method|
    it "should respond to ##{method}" do
      @articles.should respond_to(method)
    end

    describe "##{method}" do
      before do
        @resource = @model.new(:title => 'Title')
        @return = @articles.send(method, @resource)
      end

      it 'should return a Collection' do
        @return.should be_kind_of(DataMapper::Collection)
      end

      it 'should return self' do
        @return.should be_equal(@articles)
      end

      it 'should append one Resource to the Collection' do
        @articles.last.should be_equal(@resource)
      end

      it 'should relate the Resource to the Collection' do
        @resource.collection.should be_equal(@articles)
      end
    end
  end

  it 'should respond to #all' do
    @articles.should respond_to(:all)
  end

  describe '#all' do
    describe 'with no arguments' do
      before do
        @copy = @articles.dup
        @return = @resources = @articles.all
      end

      it 'should return a Collection' do
        @return.should be_kind_of(DataMapper::Collection)
      end

      it 'should return self' do
        @return.should be_equal(@articles)
      end

      it 'should be expected Resources' do
        @resources.should == [ @article ]
      end

      it 'should have the same query as original Collection' do
        @return.query.should be_equal(@articles.query)
      end

      it 'should scope the Collection' do
        skip_class = DataMapper::Associations::ManyToMany::Proxy
        pending_if "TODO: implement #{skip_class}#build", @articles.class == skip_class do
          @resources.reload.should == @copy.entries
        end
      end
    end

    describe 'with a query' do
      before do
        skip_class = DataMapper::Associations::ManyToMany::Proxy
        pending_if "TODO: fix in #{@articles.class}", @articles.class == skip_class do
          @new = @articles.create(:content => 'Newish Article')
          # search for the first 10 articles, then take the first 5, and then finally take the
          # second article from the remainder
          @copy = @articles.dup
          @return = @articles.all(:limit => 10).all(:limit => 5).all(:limit => 1, :offset => 1)
        end
      end

      it 'should return a Collection' do
        @return.should be_kind_of(DataMapper::Collection)
      end

      it 'should return a new Collection' do
        @return.should_not be_equal(@articles)
      end

      it 'should return expected Resources' do
        @return.should == [ @new ]
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
        unless @adapter.kind_of?(DataMapper::Adapters::InMemoryAdapter)
          skip_class = DataMapper::Associations::ManyToMany::Proxy
          pending_if "TODO: fix in #{@articles.class}", @articles.class == skip_class do
            @new = @articles.create(:content => 'New Article')
            @copy = @articles.dup
            @return = @articles.all(:conditions => [ 'content = ?', 'New Article' ])
          end
        end
      end

      it 'should return a Collection' do
        unless @adapter.kind_of?(DataMapper::Adapters::InMemoryAdapter)
          @return.should be_kind_of(DataMapper::Collection)
        end
      end

      it 'should return a new Collection' do
        unless @adapter.kind_of?(DataMapper::Adapters::InMemoryAdapter)
          @return.should_not be_equal(@articles)
        end
      end

      it 'should return expected Resources' do
        unless @adapter.kind_of?(DataMapper::Adapters::InMemoryAdapter)
          @return.should == [ @new ]
        end
      end

      it 'should have a different query than original Collection' do
        unless @adapter.kind_of?(DataMapper::Adapters::InMemoryAdapter)
          @return.query.should_not == @articles.query
        end
      end

      it 'should scope the Collection' do
        unless @adapter.kind_of?(DataMapper::Adapters::InMemoryAdapter)
          @return.reload.should == @copy.entries.select { |a| a.content == 'New Article' }.first(1)
        end
      end
    end

    describe 'with a query that is out of range' do
      it 'should raise an exception' do
        lambda {
          @articles.all(:limit => 10).all(:offset => 10)
        }.should raise_error(RuntimeError, 'outside range')
      end
    end
  end

  it 'should respond to #at' do
    @articles.should respond_to(:at)
  end

  describe '#at' do
    describe 'with positive offset' do
      before do
        @return = @resource = @articles.at(0)
      end

      it 'should return a Resource' do
        @return.should be_kind_of(DataMapper::Resource)
      end

      it 'should return expected Resource' do
        @resource.should == @article
      end

      it 'should relate the Resource to the Collection' do
        @resource.collection.should be_equal(@articles)
      end

      unless loaded
        it 'should not be a kicker' do
          skip = [ DataMapper::Associations::OneToMany::Proxy, DataMapper::Associations::ManyToMany::Proxy ]
          pending_if "TODO: fix in #{@articles.class}", skip.any? { |c| @articles.class == c } do
            @articles.should_not be_loaded
          end
        end
      end
    end

    describe 'with positive offset', 'after prepending to the collection' do
      before do
        @return = @resource = @articles.unshift(@other).at(0)
      end

      it 'should return a Resource' do
        @return.should be_kind_of(DataMapper::Resource)
      end

      it 'should return expected Resource' do
        @resource.should be_equal(@other)
      end

      it 'should relate the Resource to the Collection' do
        @resource.collection.should be_equal(@articles)
      end

      unless loaded
        it 'should not be a kicker' do
          skip = [ DataMapper::Associations::OneToMany::Proxy, DataMapper::Associations::ManyToMany::Proxy ]
          pending_if "TODO: fix in #{@articles.class}", skip.any? { |c| @articles.class == c } do
            @articles.should_not be_loaded
          end
        end
      end
    end

    describe 'with negative offset' do
      before do
        @return = @resource = @articles.at(-1)
      end

      it 'should return a Resource' do
        @return.should be_kind_of(DataMapper::Resource)
      end

      it 'should return expected Resource' do
        @resource.should == @article
      end

      it 'should relate the Resource to the Collection' do
        @resource.collection.should be_equal(@articles)
      end

      unless loaded
        it 'should not be a kicker' do
          skip = [ DataMapper::Associations::OneToMany::Proxy, DataMapper::Associations::ManyToMany::Proxy ]
          pending_if "TODO: fix in #{@articles.class}", skip.any? { |c| @articles.class == c } do
            @articles.should_not be_loaded
          end
        end
      end
    end

    describe 'with negative offset', 'after appending to the collection' do
      before do
        @return = @resource = @articles.push(@other).at(-1)
      end

      it 'should return a Resource' do
        @return.should be_kind_of(DataMapper::Resource)
      end

      it 'should return expected Resource' do
        @resource.should be_equal(@other)
      end

      it 'should relate the Resource to the Collection' do
        @resource.collection.should be_equal(@articles)
      end

      unless loaded
        it 'should not be a kicker' do
          skip = [ DataMapper::Associations::OneToMany::Proxy, DataMapper::Associations::ManyToMany::Proxy ]
          pending_if "TODO: fix in #{@articles.class}", skip.any? { |c| @articles.class == c } do
            @articles.should_not be_loaded
          end
        end
      end
    end
  end

  it 'should respond to #build' do
    @articles.should respond_to(:build)
  end

  describe '#build' do
    before do
      skip_class = DataMapper::Associations::ManyToMany::Proxy
      pending_if "TODO: implement #{skip_class}#build", @articles.class == skip_class do
        @return = @resource = @articles.build(:content => 'Content')
      end
    end

    it 'should return a Resource' do
      @return.should be_kind_of(DataMapper::Resource)
    end

    it 'should be a Resource with expected attributes' do
      @resource.attributes.only(:content).should == { :content => 'Content' }
    end

    it 'should be a new Resource' do
      @resource.should be_new_record
    end

    it 'should append the Resource to the Collection' do
      @articles.last.should be_equal(@resource)
    end

    it 'should use the query conditions to set default values' do
      @resource.attributes.only(:title).should == { :title => 'Sample Article' }
    end
  end

  it 'should respond to #clear' do
    @articles.should respond_to(:clear)
  end

  describe '#clear' do
    before do
      @resources = @articles.entries
      @return = @articles.clear
    end

    it 'should return a Collection' do
      @return.should be_kind_of(DataMapper::Collection)
    end

    it 'should return self' do
      @return.should be_equal(@articles)
    end

    it 'should make the Collection empty' do
      @articles.should be_empty
    end

    it 'should orphan the Resources' do
      @resources.each { |r| r.collection.should_not be_equal(@articles) }
    end
  end

  [ :collect!, :map! ].each do |method|
    it "should respond to ##{method}" do
      @articles.should respond_to(method)
    end

    describe "##{method}" do
      before do
        @resources = @articles.dup.entries
        @return = @articles.send(method) { |r| @model.new(:title => 'Title') }
      end

      it 'should return a Collection' do
        @return.should be_kind_of(DataMapper::Collection)
      end

      it 'should return self' do
        @return.should be_equal(@articles)
      end

      it 'should update the Collection inline' do
        @articles.should == [ @model.new(:title => 'Title') ]
      end

      it 'should orphan each replaced Resource in the Collection' do
        @resources.each { |r| r.collection.should_not be_equal(@articles) }
      end
    end
  end

  it 'should respond to #concat' do
    @articles.should respond_to(:concat)
  end

  describe '#concat' do
    before do
      @return = @articles.concat(@other_articles)
    end

    it 'should return a Collection' do
      @return.should be_kind_of(DataMapper::Collection)
    end

    it 'should return self' do
      @return.should be_equal(@articles)
    end

    it 'should concatenate the two collections' do
      @return.should == [ @article, @other ]
    end

    it 'should relate each Resource to the Collection' do
      @other_articles.each { |r| r.collection.should be_equal(@articles) }
    end
  end

  it 'should respond to #create' do
    @articles.should respond_to(:create)
  end

  describe '#create' do
    before do
      skip_class = DataMapper::Associations::ManyToMany::Proxy
      pending_if "TODO: fix in #{@articles.class}", @articles.class == skip_class do
        @return = @resource = @articles.create(:content => 'Content')
      end
    end

    it 'should return a Resource' do
      @return.should be_kind_of(DataMapper::Resource)
    end

    it 'should be a Resource with expected attributes' do
      @resource.attributes.only(:content).should == { :content => 'Content' }
    end

    it 'should be a saved Resource' do
      @resource.should_not be_new_record
    end

    it 'should append the Resource to the Collection' do
      @articles.last.should be_equal(@resource)
    end

    it 'should use the query conditions to set default values' do
      @resource.attributes.only(:title).should == { :title => 'Sample Article' }
    end

    it 'should not append a Resource if create fails' do
      pending 'TODO: not sure how to best spec this'
    end
  end

  it 'should respond to #delete' do
    @articles.should respond_to(:delete)
  end

  describe '#delete' do
    describe 'with a Resource within the Collection' do
      before do
        @return = @resource = @articles.delete(@article)
      end

      it 'should return a DataMapper::Resource' do
        @return.should be_kind_of(DataMapper::Resource)
      end

      it 'should be the expected Resource' do
        @resource.should == @article
      end

      it 'should remove the Resource from the Collection' do
        @articles.should_not include(@resource)
      end

      it 'should orphan the Resource' do
        @resource.collection.should_not be_equal(@articles)
      end
    end

    describe 'with a Resource not within the Collection' do
      before do
        @return = @articles.delete(@other)
      end

      it 'should return nil' do
        @return.should be_nil
      end
    end
  end

  it 'should respond to #delete_at' do
    @articles.should respond_to(:delete_at)
  end

  describe '#delete_at' do
    describe 'with an offset within the Collection' do
      before do
        @return = @resource = @articles.delete_at(0)
      end

      it 'should return a DataMapper::Resource' do
        @return.should be_kind_of(DataMapper::Resource)
      end

      it 'should be the expected Resource' do
        @resource.key.should == @article.key
      end

      it 'should remove the Resource from the Collection' do
        @articles.should_not include(@resource)
      end

      it 'should orphan the Resource' do
        @resource.collection.should_not be_equal(@articles)
      end
    end

    describe 'with an offset not within the Collection' do
      before do
        @return = @articles.delete_at(1)
      end

      it 'should return nil' do
        @return.should be_nil
      end
    end
  end

  it 'should respond to #delete_if' do
    @articles.should respond_to(:delete_if)
  end

  describe '#delete_if' do
    describe 'with a block that matches a Resource in the Collection' do
      before do
        @resources = @articles.dup.entries
        @return = @articles.delete_if { true }
      end

      it 'should return a Collection' do
        @return.should be_kind_of(DataMapper::Collection)
      end

      it 'should return self' do
        @return.should be_equal(@articles)
      end

      it 'should remove the Resources from the Collection' do
        @resources.each { |r| @articles.should_not include(r) }
      end

      it 'should orphan the Resources' do
        @resources.each { |r| r.collection.should_not be_equal(@articles) }
      end
    end

    describe 'with a block that does not match a Resource in the Collection' do
      before do
        @resources = @articles.dup.entries
        @return = @articles.delete_if { false }
      end

      it 'should return a Collection' do
        @return.should be_kind_of(DataMapper::Collection)
      end

      it 'should return self' do
        @return.should be_equal(@articles)
      end

      it 'should not modify the Collection' do
        @articles.should == @resources
      end
    end
  end

  it 'should respond to #destroy' do
    @articles.should respond_to(:destroy)
  end

  describe '#destroy' do
    before do
      @return = @articles.destroy
    end

    it 'should return true' do
      @return.should be_true
    end

    it 'should remove the Resources from the datasource' do
      @model.all(:title => 'Sample Article').should be_empty
    end

    it 'should clear the collection' do
      @articles.should be_empty
    end
  end

  it 'should respond to #destroy!' do
    @articles.should respond_to(:destroy!)
  end

  describe '#destroy!' do
    before do
      @skip_class = DataMapper::Associations::ManyToMany::Proxy
      pending_if "TODO: fix in #{@skip_class}", @articles.kind_of?(@skip_class) && !@adapter.kind_of?(DataMapper::Adapters::InMemoryAdapter) do
        @return = @articles.destroy!
      end
    end

    it 'should return true' do
      pending_if "TODO: fix in #{@skip_class}", @articles.kind_of?(@skip_class) do
        @return.should be_true
      end
    end

    it 'should remove the Resources from the datasource' do
      pending_if "TODO: fix in #{@skip_class}", @articles.kind_of?(@skip_class) do
        @model.all(:title => 'Sample Article').should be_empty
      end
    end

    it 'should clear the collection' do
      pending_if "TODO: fix in #{@skip_class}", @articles.kind_of?(@skip_class) do
        @articles.should be_empty
      end
    end

    it 'should bypass validation' do
      pending 'TODO: not sure how to best spec this'
    end
  end

  it 'should respond to #first' do
    @articles.should respond_to(:first)
  end

  describe '#first' do
    before do
      @copy = @articles.dup
    end

    describe 'with no arguments' do
      before do
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

      it 'should relate the Resource to the Collection' do
        @resource.collection.should be_equal(@articles)
      end
    end

    describe 'with no arguments', 'after prepending to the collection' do
      before do
        @return = @resource = @articles.unshift(@other).first
      end

      it 'should return a Resource' do
        @return.should be_kind_of(DataMapper::Resource)
      end

      it 'should return expected Resource' do
        @resource.should be_equal(@other)
      end

      it 'should be first Resource in the Collection' do
        @resource.should be_equal(@copy.entries.unshift(@other).first)
      end

      it 'should relate the Resource to the Collection' do
        @resource.collection.should be_equal(@articles)
      end
    end

    describe 'with a query' do
      before do
        @skip_class = DataMapper::Associations::ManyToMany::Proxy
        @return = @resource = @articles.first(:content => 'Sample')
      end

      it 'should return a Resource' do
        pending_if "TODO: fix in #{@skip_class}", @articles.kind_of?(@skip_class) do
          @return.should be_kind_of(DataMapper::Resource)
        end
      end

      it 'should should be the first Resource in the Collection matching the query' do
        pending_if "TODO: fix in #{@skip_class}", @articles.kind_of?(@skip_class) do
          @resource.should == @article
        end
      end

      it 'should relate the Resource to the Collection' do
        skip = [ DataMapper::Associations::OneToMany::Proxy, DataMapper::Associations::ManyToMany::Proxy ]
        pending_if "TODO: update #{@articles.class}#first to relate the resource to the Proxy not the underlying Collection", skip.any? { |c| @articles.class == c } do
          @resource.collection.should be_equal(@articles)
        end
      end
    end

    describe 'with limit specified' do
      before do
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
        @resources.each { |r| r.collection.should_not be_equal(@articles) }
      end
    end

    describe 'with limit specified', 'after prepending to the collection' do
      before do
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
        @resources.each { |r| r.collection.should_not be_equal(@articles) }
      end
    end

    describe 'with limit and query specified' do
      before do
        @return = @resources = @articles.first(1, :content => 'Sample')
      end

      it 'should return a Collection' do
        @return.should be_kind_of(DataMapper::Collection)
      end

      it 'should be the first N Resources in the Collection matching the query' do
        skip_class = DataMapper::Associations::ManyToMany::Proxy
        pending_if "TODO: fix in #{@articles.class}", @articles.class == skip_class do
          @resources.should == [ @article ]
        end
      end

      it 'should orphan the Resources' do
        @resources.each { |r| r.collection.should_not be_equal(@articles) }
      end
    end
  end

  it 'should respond to #get' do
    @articles.should respond_to(:get)
  end

  describe '#get' do
    describe 'with a key to a Resource within the Collection' do
      before do
        @return = @resource = @articles.get(1)
      end

      it 'should return a Resource' do
        @return.should be_kind_of(DataMapper::Resource)
      end

      it 'should be matching Resource in the Collection' do
        @resource.should == @article
      end
    end

    describe 'with a key to a Resource not within the Collection' do
      before do
        @return = @articles.get(*@other.key)
      end

      it 'should return nil' do
        @return.should be_nil
      end
    end

    describe 'with a key not typecast' do
      before do
        @return = @resource = @articles.get('1')
      end

      it 'should return a Resource' do
        @return.should be_kind_of(DataMapper::Resource)
      end

      it 'should be matching Resource in the Collection' do
        @resource.should == @article
      end
    end

    describe 'with a key to a Resource within a Collection using a limit' do
      before do
        @articles = Article.all(:limit => 1)
        @return = @resource = @articles.get(1)
      end

      it 'should return a Resource' do
        @return.should be_kind_of(DataMapper::Resource)
      end

      it 'should be matching Resource in the Collection' do
        @resource.should == @article
      end
    end

    describe 'with a key to a Resource within a Collection using an offset' do
      before do
        @articles = Article.all(:offset => 1, :limit => 1)
        @return = @resource = @articles.get(2)
      end

      it 'should return a Resource' do
        @return.should be_kind_of(DataMapper::Resource)
      end

      it 'should be matching Resource in the Collection' do
        @resource.should == @other
      end
    end
  end

  it 'should respond to #get!' do
    @articles.should respond_to(:get!)
  end

  describe '#get!' do
    describe 'with a key to a Resource within the Collection' do
      before do
        @return = @resource = @articles.get!(1)
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
        }.should raise_error(DataMapper::ObjectNotFoundError, 'Could not find Article with key [99] in collection')
      end
    end

    describe 'with a key not typecast' do
      before do
        @return = @resource = @articles.get!('1')
      end

      it 'should return a Resource' do
        @return.should be_kind_of(DataMapper::Resource)
      end

      it 'should be matching Resource in the Collection' do
        @resource.should == @article
      end
    end
  end

  it 'should respond to #insert' do
    @articles.should respond_to(:insert)
  end

  describe '#insert' do
    before do
      @resources = @other_articles
      @return = @articles.insert(0, *@resources)
    end

    it 'should return a Collection' do
      @return.should be_kind_of(DataMapper::Collection)
    end

    it 'should return self' do
      @return.should be_equal(@articles)
    end

    it 'should insert one or more Resources at a given offset' do
      @articles.should == @resources + [ @article ]
    end

    it 'should relate the Resources to the Collection' do
      @resources.each { |r| r.collection.should be_equal(@articles) }
    end
  end

  it 'should respond to #last' do
    @articles.should respond_to(:last)
  end

  describe '#last' do
    before do
      @copy = @articles.dup
    end

    describe 'with no arguments' do
      before do
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

      it 'should relate the Resource to the Collection' do
        @resource.collection.should be_equal(@articles)
      end
    end

    describe 'with no arguments', 'after appending to the collection' do
      before do
        @return = @resource = @articles.push(@other).last
      end

      it 'should return a Resource' do
        @return.should be_kind_of(DataMapper::Resource)
      end

      it 'should return expected Resource' do
        @resource.should be_equal(@other)
      end

      it 'should be last Resource in the Collection' do
        @resource.should be_equal(@copy.entries.push(@other).last)
      end

      it 'should relate the Resource to the Collection' do
        @resource.collection.should be_equal(@articles)
      end
    end

    describe 'with a query' do
      before do
        @return = @resource = @articles.last(:content => 'Sample')
      end

      it 'should return a Resource' do
        skip_class = DataMapper::Associations::ManyToMany::Proxy
        pending_if "TODO: fix in #{@articles.class}", @articles.class == skip_class do
          @return.should be_kind_of(DataMapper::Resource)
        end
      end

      it 'should should be the last Resource in the Collection matching the query' do
        skip_class = DataMapper::Associations::ManyToMany::Proxy
        pending_if "TODO: fix in #{@articles.class}", @articles.class == skip_class do
          @resource.should == @article
        end
      end

      it 'should relate the Resource to the Collection' do
        skip_class = DataMapper::Associations::ManyToMany::Proxy
        pending_if "TODO: fix in #{@articles.class}", @articles.class == skip_class do
          @resource.collection.should be_equal(@articles)
        end
      end
    end

    describe 'with limit specified' do
      before do
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
        @resources.each { |r| r.collection.should_not be_equal(@articles) }
      end
    end

    describe 'with limit specified', 'after appending to the collection' do
      before do
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
        @resources.each { |r| r.collection.should_not be_equal(@articles) }
      end
    end

    describe 'with limit and query specified' do
      before do
        @return = @resources = @articles.last(1, :content => 'Sample')
      end

      it 'should return a Collection' do
        @return.should be_kind_of(DataMapper::Collection)
      end

      it 'should be the last N Resources in the Collection matching the query' do
        skip_class = DataMapper::Associations::ManyToMany::Proxy
        pending_if "TODO: fix in #{@articles.class}", @articles.class == skip_class do
          @resources.should == [ @article ]
        end
      end

      it 'should orphan the Resources' do
        @resources.each { |r| r.collection.should_not be_equal(@articles) }
      end
    end
  end

  it 'should respond to a public model method with #method_missing' do
    @articles.should respond_to(:base_model)
  end

  it 'should respond to a belongs_to relationship method with #method_missing' do
    @articles.should respond_to(:original)
  end

  it 'should respond to a has relationship method with #method_missing' do
    @articles.should respond_to(:revisions)
  end

  describe '#method_missing' do
    describe 'with a public model method' do
      before do
        @return = @articles.base_model
      end

      it 'should return expected object' do
        @return.should == @model
      end
    end

    describe 'with a belongs_to relationship method' do
      before do
        pending 'TODO: fix for Many To Many' if @articles.class == DataMapper::Associations::ManyToMany::Proxy
        @return = @collection = @articles.original
      end

      it 'should return a Collection' do
        @return.should be_kind_of(DataMapper::Collection)
      end

      it 'should return expected Collection' do
        skip = [ DataMapper::Collection, DataMapper::Associations::OneToMany::Proxy ]
        pending_if 'TODO: fix logic to return correct entries', skip.any? { |c| @articles.class == c } do
          @collection.should == []
        end
      end
    end

    describe 'with a has relationship method' do
      describe 'with no arguments' do
        before do
          @return = @articles.revisions
        end

        it 'should return a Collection' do
          @return.should be_kind_of(DataMapper::Collection)
        end

        it 'should return expected Collection' do
          pending 'TODO: fix logic to return correct entries' do
            @collection.should == []
          end
        end
      end

      describe 'with arguments' do
        before do
          @return = @articles.revisions(:fields => [ :id ])
        end

        it 'should return a Collection' do
          @return.should be_kind_of(DataMapper::Collection)
        end

        it 'should return expected Collection' do
          pending 'TODO: fix logic to return correct entries' do
            @collection.should == []
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

  it 'should respond to #pop' do
    @articles.should respond_to(:pop)
  end

  describe '#pop' do
    before do
       @new_article = @model.create(:title => 'Sample Article')
       @articles << @new_article if @articles.loaded?
       @return = @resource = @articles.pop
    end

    it 'should return a Resource' do
      @return.should be_kind_of(DataMapper::Resource)
    end

    it 'should be the last Resource in the Collection' do
      @resource.should == @new_article
    end

    it 'should remove the Resource from the Collection' do
      @articles.should_not include(@resource)
    end

    it 'should orphan the Resource' do
      @resource.collection.should_not be_equal(@articles)
    end
  end

  it 'should respond to #push' do
    @articles.should respond_to(:push)
  end

  describe '#push' do
    before do
      @resources = [ @model.new(:title => 'Title 1'), @model.new(:title => 'Title 2') ]
      @return = @articles.push(*@resources)
    end

    it 'should return a Collection' do
      @return.should be_kind_of(DataMapper::Collection)
    end

    it 'should return self' do
      @return.should be_equal(@articles)
    end

    it 'should append the Resources to the Collection' do
      @articles.should == [ @article ] + @resources
    end

    it 'should relate the Resources to the Collection' do
      @resources.each { |r| r.collection.should be_equal(@articles) }
    end
  end

  it 'should respond to #reject!' do
    @articles.should respond_to(:reject!)
  end

  describe '#reject!' do
    describe 'with a block that matches a Resource in the Collection' do
      before do
        @resources = @articles.dup.entries
        @return = @articles.reject! { true }
      end

      it 'should return a Collection' do
        @return.should be_kind_of(DataMapper::Collection)
      end

      it 'should return self' do
        @return.should be_equal(@articles)
      end

      it 'should remove the Resources from the Collection' do
        @resources.each { |r| @articles.should_not include(r) }
      end

      it 'should orphan the Resources' do
        @resources.each { |r| r.collection.should_not be_equal(@articles) }
      end
    end

    describe 'with a block that does not match a Resource in the Collection' do
      before do
        @resources = @articles.dup.entries
        @return = @articles.reject! { false }
      end

      it 'should return nil' do
        @return.should == nil
      end

      it 'should not modify the Collection' do
        @articles.should == @resources
      end
    end
  end

  it 'should respond to #reload' do
    @articles.should respond_to(:reload)
  end

  describe '#reload' do
    describe 'with no arguments' do
      before do
        @resources = @articles.dup.entries
        @return = @collection = @articles.reload
      end

      it 'should return a Collection' do
        @return.should be_kind_of(DataMapper::Collection)
      end

      it 'should return self' do
        @return.should be_equal(@articles)
      end

      it 'should have non-lazy query fields loaded' do
        @return.each { |r| { :title => true, :content => false }.each { |a,c| r.attribute_loaded?(a).should == c } }
      end
    end

    describe 'with a Hash query' do
      before do
        @resources = @articles.dup.entries
        @return = @collection = @articles.reload(:fields => [ :content ])  # :title is a default field
      end

      it 'should return a Collection' do
        @return.should be_kind_of(DataMapper::Collection)
      end

      it 'should return self' do
        @return.should be_equal(@articles)
      end

      it 'should have all query fields loaded' do
        @return.each { |r| { :title => true, :content => true }.each { |a,c| r.attribute_loaded?(a).should == c } }
      end
    end

    describe 'with a Query' do
      before do
        @resources = @articles.dup.entries
        @query = DataMapper::Query.new(@repository, @model, :fields => [ :content ])
        @return = @collection = @articles.reload(@query)
      end

      it 'should return a Collection' do
        @return.should be_kind_of(DataMapper::Collection)
      end

      it 'should return self' do
        @return.should be_equal(@articles)
      end

      it 'should have all query fields loaded' do
        @return.each { |r| { :title => false, :content => true }.each { |a,c| r.attribute_loaded?(a).should == c } }
      end
    end
  end

  it 'should respond to #replace' do
    @articles.should respond_to(:replace)
  end

  describe '#replace' do
    before do
      @resources = @articles.dup.entries
      @return = @articles.replace(@other_articles)
    end

    it 'should return a Collection' do
      @return.should be_kind_of(DataMapper::Collection)
    end

    it 'should return self' do
      @return.should be_equal(@articles)
    end

    it 'should update the Collection with new Resources' do
      @articles.should == @other_articles
    end

    it 'should relate each Resource added to the Collection' do
      @articles.each { |r| r.collection.should be_equal(@articles) }
    end

    it 'should orphan each Resource removed from the Collection' do
      @resources.each { |r| r.collection.should_not be_equal(@articles) }
    end
  end

  it 'should respond to #reverse' do
    @articles.should respond_to(:reverse)
  end

  describe '#reverse' do
    before do
      @new_article = @model.create(:title => 'Sample Article')
      @articles << @new_article if @articles.loaded?
      @return = @articles.reverse
    end

    it 'should return a Collection' do
      @return.should be_kind_of(DataMapper::Collection)
    end

    it 'should return a Collection with reversed entries' do
      @return.should == [ @new_article, @article ]
    end
  end

  it 'should respond to #shift' do
    @articles.should respond_to(:shift)
  end

  describe '#shift' do
    before do
      @new_article = @model.create(:title => 'Sample Article')
      @articles << @new_article if @articles.loaded?
      @return = @resource = @articles.shift
    end

    it 'should return a Resource' do
      @return.should be_kind_of(DataMapper::Resource)
    end

    it 'should be the first Resource in the Collection' do
      @resource.key.should == @article.key
    end

    it 'should remove the Resource from the Collection' do
      @articles.should_not include(@resource)
    end

    it 'should orphan the Resource' do
      @resource.collection.should_not be_equal(@articles)
    end
  end

  [ :slice, :[] ].each do |method|
    it "should respond to ##{method}" do
      @articles.should respond_to(method)
    end

    describe "##{method}" do
      before do
        skip_class = DataMapper::Associations::ManyToMany::Proxy
        pending_if "TODO: fix in #{@articles.class}", @articles.class == skip_class do
          1.upto(10) { |n| @articles.create(:content => "Article #{n}") }
        end

        @copy = @articles.dup
      end

      describe 'with a positive offset' do
        before do
          @return = @resource = @articles.send(method, 0)
        end

        it 'should return a Resource' do
          @return.should be_kind_of(DataMapper::Resource)
        end

        it 'should return expected Resource' do
          @return.should == @copy.entries.send(method, 0)
        end

        it 'should not remove the Resource from the Collection' do
          @articles.should include(@resource)
        end

        it 'should relate the Resource to the Collection' do
          @resource.collection.should be_equal(@articles)
        end
      end

      describe 'with a positive offset and length' do
        before do
          @return = @resources = @articles.send(method, 5, 5)
        end

        it 'should return a Collection' do
          @return.should be_kind_of(DataMapper::Collection)
        end

        it 'should return the expected Resource' do
          @return.should == @copy.entries.send(method, 5, 5)
        end

        it 'should not remove the Resources from the Collection' do
          @resources.each { |r| @articles.should include(r) }
        end

        it 'should orphan the Resources' do
          @resources.each { |r| r.collection.should_not be_equal(@articles) }
        end

        it 'should scope the Collection' do
          @resources.reload.should == @copy.entries.send(method, 5, 5)
        end
      end

      describe 'with a positive range' do
        before do
          @return = @resources = @articles.send(method, 5..10)
        end

        it 'should return a Collection' do
          @return.should be_kind_of(DataMapper::Collection)
        end

        it 'should return the expected Resources' do
          @return.should == @copy.entries.send(method, 5..10)
        end

        it 'should not remove the Resources from the Collection' do
          @resources.each { |r| @articles.should include(r) }
        end

        it 'should orphan the Resources' do
          @resources.each { |r| r.collection.should_not be_equal(@articles) }
        end

        it 'should scope the Collection' do
          @resources.reload.should == @copy.entries.send(method, 5..10)
        end
      end

      describe 'with a negative offset' do
        before do
          @return = @resource = @articles.send(method, -1)
        end

        it 'should return a Resource' do
          @return.should be_kind_of(DataMapper::Resource)
        end

        it 'should return expected Resource' do
          @return.should == @copy.entries.send(method, -1)
        end

        it 'should not remove the Resource from the Collection' do
          @articles.should include(@resource)
        end

        it 'should relate the Resource to the Collection' do
          @resource.collection.should be_equal(@articles)
        end
      end

      describe 'with a negative offset and length' do
        before do
          @return = @resources = @articles.send(method, -5, 5)
        end

        it 'should return a Collection' do
          @return.should be_kind_of(DataMapper::Collection)
        end

        it 'should return the expected Resources' do
          @return.should == @copy.entries.send(method, -5, 5)
        end

        it 'should not remove the Resources from the Collection' do
          @resources.each { |r| @articles.should include(r) }
        end

        it 'should orphan the Resources' do
          @resources.each { |r| r.collection.should_not be_equal(@articles) }
        end

        it 'should scope the Collection' do
          @resources.reload.should == @copy.entries.send(method, -5, 5)
        end
      end

      describe 'with a negative range' do
        before do
          @return = @resources = @articles.send(method, -5..-2)
        end

        it 'should return a Collection' do
          @return.should be_kind_of(DataMapper::Collection)
        end

        it 'should return the expected Resources' do
          @return.to_a.should == @copy.entries.send(method, -5..-2)
        end

        it 'should not remove the Resources from the Collection' do
          @resources.each { |r| @articles.should include(r) }
        end

        it 'should orphan the Resources' do
          @resources.each { |r| r.collection.should_not be_equal(@articles) }
        end

        it 'should scope the Collection' do
          @resources.reload.should == @copy.entries.send(method, -5..-2)
        end
      end

      describe 'with an offset not within the Collection' do
        before do
          @return = @articles.send(method, 12)
        end

        it 'should return nil' do
          @return.should be_nil
        end
      end

      describe 'with an offset and length not within the Collection' do
        before do
          @return = @articles.send(method, 12, 1)
        end

        it 'should return nil' do
          @return.should be_nil
        end
      end

      describe 'with a range not within the Collection' do
        before do
          @return = @articles.send(method, 12..13)
        end

        it 'should return nil' do
          @return.should be_nil
        end
      end
    end
  end

  it 'should respond to #slice!' do
    @articles.should respond_to(:slice)
  end

  describe '#slice!' do
    before do
      skip_class = DataMapper::Associations::ManyToMany::Proxy
      pending_if "TODO: fix in #{@articles.class}", @articles.class == skip_class do
        1.upto(10) { |n| @articles.create(:content => "Article #{n}") }
      end

      @copy = @articles.dup
    end

    describe 'with a positive offset' do
      before do
        @return = @resource = @articles.slice!(0)
      end

      it 'should return a Resource' do
        @return.should be_kind_of(DataMapper::Resource)
      end

      it 'should return expected Resource' do
        @return.should == @article
      end

      it 'should return the same as Array#slice!' do
        @return.should == @copy.entries.slice!(0)
      end

      it 'should remove the Resource from the Collection' do
        @articles.should_not include(@resource)
      end

      it 'should orphan the Resource' do
        @resource.collection.should_not be_equal(@articles)
      end
    end

    describe 'with a positive offset and length' do
      before do
        @return = @resources = @articles.slice!(5, 5)
      end

      it 'should return a Collection' do
        @return.should be_kind_of(DataMapper::Collection)
      end

      it 'should return the expected Resource' do
        @return.should == @copy.entries.slice!(5, 5)
      end

      it 'should remove the Resources from the Collection' do
        @resources.each { |r| @articles.should_not include(r) }
      end

      it 'should orphan the Resources' do
        @resources.each { |r| r.collection.should_not be_equal(@articles) }
      end

      it 'should scope the Collection' do
        @resources.reload.should == @copy.entries.slice!(5, 5)
      end
    end

    describe 'with a positive range' do
      before do
        @return = @resources = @articles.slice!(5..10)
      end

      it 'should return a Collection' do
        @return.should be_kind_of(DataMapper::Collection)
      end

      it 'should return the expected Resources' do
        @return.should == @copy.entries.slice!(5..10)
      end

      it 'should remove the Resources from the Collection' do
        @resources.each { |r| @articles.should_not include(r) }
      end

      it 'should orphan the Resources' do
        @resources.each { |r| r.collection.should_not be_equal(@articles) }
      end

      it 'should scope the Collection' do
        @resources.reload.should == @copy.entries.slice!(5..10)
      end
    end

    describe 'with a negative offset' do
      before do
        @return = @resource = @articles.slice!(-1)
      end

      it 'should return a Resource' do
        @return.should be_kind_of(DataMapper::Resource)
      end

      it 'should return expected Resource' do
        @return.should == @copy.entries.slice!(-1)
      end

      it 'should remove the Resource from the Collection' do
        @articles.should_not include(@resource)
      end

      it 'should orphan the Resource' do
        @resource.collection.should_not be_equal(@articles)
      end
    end

    describe 'with a negative offset and length' do
      before do
        @return = @resources = @articles.slice!(-5, 5)
      end

      it 'should return a Collection' do
        @return.should be_kind_of(DataMapper::Collection)
      end

      it 'should return the expected Resources' do
        @return.should == @copy.entries.slice!(-5, 5)
      end

      it 'should remove the Resources from the Collection' do
        @resources.each { |r| @articles.should_not include(r) }
      end

      it 'should orphan the Resources' do
        @resources.each { |r| r.collection.should_not be_equal(@articles) }
      end

      it 'should scope the Collection' do
        @resources.reload.should == @copy.entries.slice!(-5, 5)
      end
    end

    describe 'with a negative range' do
      before do
        @return = @resources = @articles.slice!(-3..-2)
      end

      it 'should return a Collection' do
        @return.should be_kind_of(DataMapper::Collection)
      end

      it 'should return the expected Resources' do
        @return.should == @copy.entries.slice!(-3..-2)
      end

      it 'should remove the Resources from the Collection' do
        @resources.each { |r| @articles.should_not include(r) }
      end

      it 'should orphan the Resources' do
        @resources.each { |r| r.collection.should_not be_equal(@articles) }
      end

      it 'should scope the Collection' do
        @resources.reload.should == @copy.entries.slice!(-3..-2)
      end
    end

    describe 'with an offset not within the Collection' do
      before do
        @return = @articles.slice!(12)
      end

      it 'should return nil' do
        @return.should be_nil
      end
    end

    describe 'with an offset and length not within the Collection' do
      before do
        @return = @articles.slice!(12, 1)
      end

      it 'should return nil' do
        @return.should be_nil
      end
    end

    describe 'with a range not within the Collection' do
      before do
        @return = @articles.slice!(12..13)
      end

      it 'should return nil' do
        @return.should be_nil
      end
    end
  end

  it 'should respond to #sort!' do
    @articles.should respond_to(:sort!)
  end

  describe '#sort!' do
    describe 'without a block' do
      before do
        # NOTE: DataMapper::Resource#<=> should use the Model#default_order to determine the
        # sort order for the Resource instances.  It should use the same approach as
        # InMemoryAdapter#sorted_results
        pending 'TODO: implement DataMapper::Resource#<=>, and include Comparable in DataMapper::Resource' do
          @return = @other_articles.push(*@articles).sort!
        end
      end

      it 'should return a Collection' do
        @return.should be_kind_of(DataMapper::Collection)
      end

      it 'should return self' do
        @return.should be_equal(@articles)
      end

      it 'should modify and sort the Collection using default sort order' do
        @articles.should == [ @article, @other ]
      end
    end

    describe 'with a block' do
      before do
        @new_article = @model.create(:title => 'Sample Article')
        @articles << @new_article if @articles.loaded?
        @return = @articles.sort! { |a,b| b.id <=> a.id }
      end

      it 'should return a Collection' do
        @return.should be_kind_of(DataMapper::Collection)
      end

      it 'should return self' do
        @return.should be_equal(@articles)
      end

      it 'should modify and sort the Collection using supplied block' do
        @articles.should == [ @new_article, @article ]
      end
    end
  end

  [ :splice, :[]= ].each do |method|
    it "should respond to ##{method}" do
      @articles.should respond_to(method)
    end

    describe "##{method}" do
      before do
        skip_class = DataMapper::Associations::ManyToMany::Proxy
        pending_if "TODO: fix in #{@articles.class}", @articles.class == skip_class do
          orphans = (1..10).map do |n|
            @articles.create(:content => "Article #{n}")
            @articles.pop  # remove the article from the tail
          end

          @articles.unshift(*orphans.first(5))
          @articles.concat(orphans.last(5))
        end

        @copy = @articles.dup
        @new = @model.new(:content => 'New Article')
      end

      describe 'with a positive offset and a Resource' do
        before do
          @original = @copy[1]
          @original.collection.should be_equal(@articles)

          @return = @resource = @articles.send(method, 1, @new)
        end

        it 'should return a Resource' do
          @return.should be_kind_of(DataMapper::Resource)
        end

        it 'should return expected Resource' do
          @return.should be_equal(@new)
        end

        it 'should return the same as Array#[]=' do
          @return.should == @copy.entries[1] = @new
        end

        it 'should include the Resource in the Collection' do
          @articles.should include(@resource)
        end

        it 'should relate the Resource to the Collection' do
          @resource.collection.should be_equal(@articles)
        end

        it 'should orphan the original Resource' do
          @original.collection.should_not be_equal(@articles)
        end
      end

      describe 'with a positive offset and length and a Resource' do
        before do
          @original = @copy[2]
          @original.collection.should be_equal(@articles)

          @return = @resource = @articles.send(method, 2, 1, @new)
        end

        it 'should return a Resource' do
          @return.should be_kind_of(DataMapper::Resource)
        end

        it 'should return the expected Resource' do
          @return.should be_equal(@new)
        end

        it 'should return the same as Array#[]=' do
          @return.should == @copy.entries[2, 1] = @new
        end

        it 'should include the Resource in the Collection' do
          @articles.should include(@resource)
        end

        it 'should orphan the original Resource' do
          @original.collection.should_not be_equal(@articles)
        end
      end

      describe 'with a positive range and a Resource' do
        before do
          @originals = @copy.values_at(2..3)
          @originals.each { |o| o.collection.should be_equal(@articles) }

          @return = @resource = @articles.send(method, 2..3, @new)
        end

        it 'should return a Resource' do
          @return.should be_kind_of(DataMapper::Resource)
        end

        it 'should return the expected Resources' do
          @return.should be_equal(@new)
        end

        it 'should return the same as Array#[]=' do
          @return.should == @copy.entries[2..3] = @new
        end

        it 'should include the Resource in the Collection' do
          @articles.should include(@resource)
        end

        it 'should orphan the original Resources' do
          @originals.each { |o| o.collection.should_not be_equal(@articles) }
        end
      end

      describe 'with a negative offset and a Resource' do
        before do
          @original = @copy[-1]
          @original.collection.should be_equal(@articles)

          @return = @resource = @articles.send(method, -1, @new)
        end

        it 'should return a Resource' do
          @return.should be_kind_of(DataMapper::Resource)
        end

        it 'should return expected Resource' do
          @return.should be_equal(@new)
        end

        it 'should return the same as Array#[]=' do
          @return.should == @copy.entries[-1] = @new
        end

        it 'should include the Resource in the Collection' do
          @articles.should include(@resource)
        end

        it 'should relate the Resource to the Collection' do
          @resource.collection.should be_equal(@articles)
        end

        it 'should orphan the original Resource' do
          @original.collection.should_not be_equal(@articles)
        end
      end

      describe 'with a negative offset and length and a Resource' do
        before do
          @original = @copy[-2]
          @original.collection.should be_equal(@articles)

          @return = @resource = @articles.send(method, -2, 1, @new)
        end

        it 'should return a Resource' do
          @return.should be_kind_of(DataMapper::Resource)
        end

        it 'should return the expected Resource' do
          @return.should be_equal(@new)
        end

        it 'should return the same as Array#[]=' do
          @return.should == @copy.entries[-2, 1] = @new
        end

        it 'should include the Resource in the Collection' do
          @articles.should include(@resource)
        end

        it 'should orphan the original Resource' do
          @original.collection.should_not be_equal(@articles)
        end
      end

      describe 'with a negative range and a Resource' do
        before do
          @originals = @copy.values_at(-3..-2)
          @originals.each { |o| o.collection.should be_equal(@articles) }

          @return = @resource = @articles.send(method, -3..-2, @new)
        end

        it 'should return a Resource' do
          @return.should be_kind_of(DataMapper::Resource)
        end

        it 'should return the expected Resources' do
          @return.should be_equal(@new)
        end

        it 'should return the same as Array#[]=' do
          @return.should == @copy.entries[-3..-2] = @new
        end

        it 'should include the Resource in the Collection' do
          @articles.should include(@resource)
        end

        it 'should orphan the original Resources' do
          @originals.each { |o| o.collection.should_not be_equal(@articles) }
        end
      end
    end
  end

  it 'should respond to #unshift' do
    @articles.should respond_to(:unshift)
  end

  describe '#unshift' do
    before do
      @resources = [ @model.new(:title => 'Title 1'), @model.new(:title => 'Title 2') ]
      @return = @articles.unshift(*@resources)
    end

    it 'should return a Collection' do
      @return.should be_kind_of(DataMapper::Collection)
    end

    it 'should return self' do
      @return.should be_equal(@articles)
    end

    it 'should prepend the Resources to the Collection' do
      @articles.should == @resources + [ @article ]
    end

    it 'should relate the Resources to the Collection' do
      @resources.each { |r| r.collection.should be_equal(@articles) }
    end
  end

  it 'should respond to #update' do
    @articles.should respond_to(:update)
  end

  describe '#update' do
    describe 'with no arguments' do
      before do
        @return = @articles.update
      end

      it 'should return true' do
        @return.should be_true
      end
    end

    describe 'with arguments' do
      before do
        @return = @articles.update(:title => 'Updated Title')
      end

      it 'should return true' do
        @return.should be_true
      end

      it 'should update attributes of all Resources' do
        @articles.each { |r| r.title.should == 'Updated Title' }
      end

      it 'should persist the changes' do
        @model.get(*@article.key).title.should == 'Updated Title'
      end
    end
  end

  it 'should respond to #update!' do
    @articles.should respond_to(:update!)
  end

  describe '#update!' do
    describe 'with no arguments' do
      before do
        @return = @articles.update!
      end

      it 'should return true' do
        @return.should be_true
      end
    end

    describe 'with arguments' do
      before do
        @skip_class = DataMapper::Associations::ManyToMany::Proxy
        pending_if "TODO: implement #{@skip_class}#update!", @articles.kind_of?(@skip_class) && !@adapter.kind_of?(DataMapper::Adapters::InMemoryAdapter) do
          @return = @articles.update!(:title => 'Updated Title')
        end
      end

      it 'should return true' do
        pending_if "TODO: implement #{@skip_class}#update!", @articles.kind_of?(@skip_class) && @adapter.kind_of?(DataMapper::Adapters::InMemoryAdapter) do
          @return.should be_true
        end
      end

      it 'should bypass validation' do
        pending 'TODO: not sure how to best spec this'
      end

      it 'should update attributes of all Resources' do
        pending_if "TODO: implement #{@skip_class}#update!", @articles.kind_of?(@skip_class) do
          @articles.each { |r| r.title.should == 'Updated Title' }
        end
      end

      it 'should persist the changes' do
        pending_if "TODO: implement #{@skip_class}#update!", @articles.kind_of?(@skip_class) do
          @model.get(*@article.key).title.should == 'Updated Title'
        end
      end
    end
  end
end
