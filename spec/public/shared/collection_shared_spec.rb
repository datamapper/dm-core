share_examples_for 'A public Collection' do
  before :all do
    %w[ @article_model @article @other @original @articles @other_articles ].each do |ivar|
      raise "+#{ivar}+ should be defined in before block" unless instance_variable_defined?(ivar)
      raise "+#{ivar}+ should not be nil in before block" unless instance_variable_get(ivar)
    end

    @articles.loaded?.should == loaded
  end

  before :all do
    @no_join = defined?(DataMapper::Adapters::InMemoryAdapter) && @adapter.kind_of?(DataMapper::Adapters::InMemoryAdapter) ||
               defined?(DataMapper::Adapters::YamlAdapter)     && @adapter.kind_of?(DataMapper::Adapters::YamlAdapter)

    @one_to_many  = @articles.kind_of?(DataMapper::Associations::OneToMany::Collection)
    @many_to_many = @articles.kind_of?(DataMapper::Associations::ManyToMany::Collection)

    @skip = @no_join && @many_to_many
  end

  before do
    pending if @skip
  end

  subject { @articles }

  it { should respond_to(:<<) }

  describe '#<<' do
    before :all do
      @resource = @article_model.new(:title => 'Title')

      @return = @articles << @resource
    end

    it 'should return a Collection' do
      @return.should be_kind_of(DataMapper::Collection)
    end

    it 'should return self' do
      @return.should equal(@articles)
    end

    it 'should append one Resource to the Collection' do
      @articles.last.should equal(@resource)
    end
  end

  it { should respond_to(:blank?) }

  describe '#blank?' do
    describe 'when the collection is empty' do
      it 'should be true' do
        @articles.clear.blank?.should be_true
      end
    end

    describe 'when the collection is not empty' do
      it 'should be false' do
        @articles.blank?.should be_false
      end
    end
  end

  it { should respond_to(:clean?) }

  describe '#clean?' do
    describe 'with all clean resources in the collection' do
      it 'should return true' do
        @articles.clean?.should be_true
      end
    end

    describe 'with a dirty resource in the collection' do
      before :all do
        @articles.each { |r| r.content = 'Changed' }
      end

      it 'should return true' do
        @articles.clean?.should be_false
      end
    end
  end

  it { should respond_to(:clear) }

  describe '#clear' do
    before :all do
      @resources = @articles.entries

      @return = @articles.clear
    end

    it 'should return a Collection' do
      @return.should be_kind_of(DataMapper::Collection)
    end

    it 'should return self' do
      @return.should equal(@articles)
    end

    it 'should make the Collection empty' do
      @articles.should be_empty
    end
  end

  [ :collect!, :map! ].each do |method|
    it { should respond_to(method) }

    describe "##{method}" do
      before :all do
        @resources = @articles.dup.entries

        @return = @articles.send(method) { |resource| @article_model.new(:title => 'Ignored Title', :content => 'New Content') }
      end

      it 'should return a Collection' do
        @return.should be_kind_of(DataMapper::Collection)
      end

      it 'should return self' do
        @return.should equal(@articles)
      end

      it 'should update the Collection inline' do
        @articles.each { |resource| resource.attributes.only(:title, :content).should == { :title => 'Sample Article', :content => 'New Content' } }
      end
    end
  end

  it { should respond_to(:concat) }

  describe '#concat' do
    before :all do
      @return = @articles.concat(@other_articles)
    end

    it 'should return a Collection' do
      @return.should be_kind_of(DataMapper::Collection)
    end

    it 'should return self' do
      @return.should equal(@articles)
    end

    it 'should concatenate the two collections' do
      @return.should == [ @article, @other ]
    end
  end

  [ :create, :create! ].each do |method|
    it { should respond_to(method) }

    describe "##{method}" do
      describe 'when scoped to a property' do
        before :all do
          @return = @resource = @articles.send(method)
        end

        it 'should return a Resource' do
          @return.should be_kind_of(DataMapper::Resource)
        end

        it 'should be a saved Resource' do
          @resource.should be_saved
        end

        it 'should append the Resource to the Collection' do
          @articles.last.should equal(@resource)
        end

        it 'should use the query conditions to set default values' do
          @resource.title.should == 'Sample Article'
        end

        it 'should not append a Resource if create fails' do
          pending 'TODO: not sure how to best spec this'
        end
      end

      describe 'when scoped to the key' do
        before :all do
          @articles = @articles.all(:id => 1)

          @return = @resource = @articles.send(method)
        end

        it 'should return a Resource' do
          @return.should be_kind_of(DataMapper::Resource)
        end

        it 'should be a saved Resource' do
          @resource.should be_saved
        end

        it 'should append the Resource to the Collection' do
          @articles.last.should equal(@resource)
        end

        it 'should not use the query conditions to set default values' do
          @resource.id.should_not == 1
        end

        it 'should not append a Resource if create fails' do
          pending 'TODO: not sure how to best spec this'
        end
      end

      describe 'when scoped to a property with multiple values' do
        before :all do
          @articles = @articles.all(:content => %w[ Sample Other ])

          @return = @resource = @articles.send(method)
        end

        it 'should return a Resource' do
          @return.should be_kind_of(DataMapper::Resource)
        end

        it 'should be a saved Resource' do
          @resource.should be_saved
        end

        it 'should append the Resource to the Collection' do
          @articles.last.should equal(@resource)
        end

        it 'should not use the query conditions to set default values' do
          @resource.content.should be_nil
        end

        it 'should not append a Resource if create fails' do
          pending 'TODO: not sure how to best spec this'
        end
      end

      describe 'when scoped with a condition other than eql' do
        before :all do
          @articles = @articles.all(:content.not => 'Sample')

          @return = @resource = @articles.send(method)
        end

        it 'should return a Resource' do
          @return.should be_kind_of(DataMapper::Resource)
        end

        it 'should be a saved Resource' do
          @resource.should be_saved
        end

        it 'should append the Resource to the Collection' do
          @articles.last.should equal(@resource)
        end

        it 'should not use the query conditions to set default values' do
          @resource.content.should be_nil
        end

        it 'should not append a Resource if create fails' do
          pending 'TODO: not sure how to best spec this'
        end
      end
    end
  end

  [ :difference, :- ].each do |method|
    it { should respond_to(method) }

    describe "##{method}" do
      subject { @articles.send(method, @other_articles) }

      describe 'with a Collection' do
        it { should be_kind_of(DataMapper::Collection) }

        it { should == [ @article ] }

        it { subject.query.should == @articles.query.difference(@other_articles.query) }

        it { should == @articles.to_a - @other_articles.to_a }
      end

      describe 'with an Array' do
        before { @other_articles = @other_articles.to_ary }

        it { should be_kind_of(DataMapper::Collection) }

        it { should == [ @article ] }

        it { should == @articles.to_a - @other_articles.to_a }
      end

      describe 'with a Set' do
        before { @other_articles = @other_articles.to_set }

        it { should be_kind_of(DataMapper::Collection) }

        it { should == [ @article ] }

        it { should == @articles.to_a - @other_articles.to_a }
      end
    end
  end

  it { should respond_to(:delete) }

  describe '#delete' do
    describe 'with a Resource within the Collection' do
      before :all do
        @return = @resource = @articles.delete(@article)
      end

      it 'should return a DataMapper::Resource' do
        @return.should be_kind_of(DataMapper::Resource)
      end

      it 'should be the expected Resource' do
        # compare keys because FK attributes may have been altered
        # when removing from the Collection
        @resource.key.should == @article.key
      end

      it 'should remove the Resource from the Collection' do
        @articles.should_not be_include(@resource)
      end
    end

    describe 'with a Resource not within the Collection' do
      before :all do
        @return = @articles.delete(@other)
      end

      it 'should return nil' do
        @return.should be_nil
      end
    end
  end

  it { should respond_to(:delete_at) }

  describe '#delete_at' do
    describe 'with an offset within the Collection' do
      before :all do
        @return = @resource = @articles.delete_at(0)
      end

      it 'should return a DataMapper::Resource' do
        @return.should be_kind_of(DataMapper::Resource)
      end

      it 'should be the expected Resource' do
        @resource.key.should == @article.key
      end

      it 'should remove the Resource from the Collection' do
        @articles.should_not be_include(@resource)
      end
    end

    describe 'with an offset not within the Collection' do
      before :all do
        @return = @articles.delete_at(1)
      end

      it 'should return nil' do
        @return.should be_nil
      end
    end
  end

  it { should respond_to(:delete_if) }

  describe '#delete_if' do
    describe 'with a block that matches a Resource in the Collection' do
      before :all do
        @resources = @articles.dup.entries

        @return = @articles.delete_if { true }
      end

      it 'should return a Collection' do
        @return.should be_kind_of(DataMapper::Collection)
      end

      it 'should return self' do
        @return.should equal(@articles)
      end

      it 'should remove the Resources from the Collection' do
        @resources.each { |resource| @articles.should_not be_include(resource) }
      end
    end

    describe 'with a block that does not match a Resource in the Collection' do
      before :all do
        @resources = @articles.dup.entries

        @return = @articles.delete_if { false }
      end

      it 'should return a Collection' do
        @return.should be_kind_of(DataMapper::Collection)
      end

      it 'should return self' do
        @return.should equal(@articles)
      end

      it 'should not modify the Collection' do
        @articles.should == @resources
      end
    end
  end

  [ :destroy, :destroy! ].each do |method|
    it { should respond_to(method) }

    describe "##{method}" do
      describe 'on a normal collection' do
        before :all do
          @return = @articles.send(method)
        end

        it 'should return true' do
          @return.should be_true
        end

        it 'should remove the Resources from the datasource' do
          @article_model.all(:title => 'Sample Article').should be_empty
        end

        it 'should clear the collection' do
          @articles.should be_empty
        end
      end

      describe 'on a limited collection' do
        before :all do
          @other   = @articles.create
          @limited = @articles.all(:limit => 1)

          @return = @limited.send(method)
        end

        it 'should return true' do
          @return.should be_true
        end

        it 'should remove the Resources from the datasource' do
          @article_model.all(:title => 'Sample Article').should == [ @other ]
        end

        it 'should clear the collection' do
          @limited.should be_empty
        end

        it 'should not destroy the other Resource' do
          @article_model.get(*@other.key).should_not be_nil
        end
      end
    end
  end

  it { should respond_to(:dirty?) }

  describe '#dirty?' do
    describe 'with all clean resources in the collection' do
      it 'should return false' do
        @articles.dirty?.should be_false
      end
    end

    describe 'with a dirty resource in the collection' do
      before :all do
        @articles.each { |r| r.content = 'Changed' }
      end

      it 'should return true' do
        @articles.dirty?.should be_true
      end
    end
  end

  # TODO: move this to enumerable_shared_spec.rb
  it { should respond_to(:each) }

  describe '#each' do
    before :all do
      rescue_if @skip do
        @resources = @articles.dup.entries
        @resources.should_not be_empty

        @yield       = []
        @collections = []

        @return = @articles.each do |resource|
          @yield       << resource
          @collections << [ resource, resource.collection.object_id ]
        end
      end
    end

    it 'should return a Collection' do
      @return.should be_kind_of(DataMapper::Collection)
    end

    it 'should return self' do
      @return.should equal(@articles)
    end

    it 'should yield to each entry' do
      @yield.should == @articles
    end

    it 'should yield Resources' do
      @yield.each { |resource| resource.should be_kind_of(DataMapper::Resource) }
    end

    it 'should relate the Resource collection to the Collection within the block only' do
      pending_if 'Fix SEL for m:m', @many_to_many do
        @collections.each do |resource, object_id|
          resource.collection.should_not equal(@articles)  # collection outside block
          object_id.should == @articles.object_id          # collection inside block
        end
      end
    end
  end

  it { should respond_to(:insert) }

  describe '#insert' do
    before :all do
      @resources = @other_articles

      @return = @articles.insert(0, *@resources)
    end

    it 'should return a Collection' do
      @return.should be_kind_of(DataMapper::Collection)
    end

    it 'should return self' do
      @return.should equal(@articles)
    end

    it 'should insert one or more Resources at a given offset' do
      @articles.should == @resources << @article
    end
  end

  it { should respond_to(:inspect) }

  describe '#inspect' do
    before :all do
      @copy = @articles.dup
      @copy << @article_model.new(:title => 'Ignored Title', :content => 'Other Article')

      @return = @copy.inspect
    end

    it { @return.should match(/\A\[.*\]\z/) }

    it { @return.should match(/\bid=#{@article.id}\b/) }
    it { @return.should match(/\bid=nil\b/) }

    it { @return.should match(/\btitle=\"Sample Article\"\s/) }
    it { @return.should_not match(/\btitle=\"Ignored Title\"\s/) }
    it { @return.should match(/\bcontent=\"Other Article\"\s/) }
  end

  [ :intersection, :& ].each do |method|
    it { should respond_to(method) }

    describe "##{method}" do
      subject { @articles.send(method, @other_articles) }

      describe 'with a Collection' do
        it { should be_kind_of(DataMapper::Collection) }

        it { should == [] }

        it { subject.query.should == @articles.query.intersection(@other_articles.query) }

        it { should == @articles.to_a & @other_articles.to_a }
      end

      describe 'with an Array' do
        before { @other_articles = @other_articles.to_ary }

        it { should be_kind_of(DataMapper::Collection) }

        it { should == [] }

        it { should == @articles.to_a & @other_articles.to_a }
      end

      describe 'with a Set' do
        before { @other_articles = @other_articles.to_set }

        it { should be_kind_of(DataMapper::Collection) }

        it { should == [] }

        it { should == @articles.to_a & @other_articles.to_a }
      end
    end
  end

  it { should respond_to(:new) }

  describe '#new' do
    describe 'when scoped to a property' do
      before :all do
        @return = @resource = @articles.new
      end

      it 'should return a Resource' do
        @return.should be_kind_of(DataMapper::Resource)
      end

      it 'should be a new Resource' do
        @resource.should be_new
      end

      it 'should append the Resource to the Collection' do
        @articles.last.should equal(@resource)
      end

      it 'should use the query conditions to set default values' do
        @resource.title.should == 'Sample Article'
      end
    end

    describe 'when scoped to the key' do
      before :all do
        @articles = @articles.all(:id => 1)

        @return = @resource = @articles.new
      end

      it 'should return a Resource' do
        @return.should be_kind_of(DataMapper::Resource)
      end

      it 'should be a new Resource' do
        @resource.should be_new
      end

      it 'should append the Resource to the Collection' do
        @articles.last.should equal(@resource)
      end

      it 'should not use the query conditions to set default values' do
        @resource.id.should be_nil
      end
    end

    describe 'when scoped to a property with multiple values' do
      before :all do
        @articles = @articles.all(:content => %w[ Sample Other ])

        @return = @resource = @articles.new
      end

      it 'should return a Resource' do
        @return.should be_kind_of(DataMapper::Resource)
      end

      it 'should be a new Resource' do
        @resource.should be_new
      end

      it 'should append the Resource to the Collection' do
        @articles.last.should equal(@resource)
      end

      it 'should not use the query conditions to set default values' do
        @resource.content.should be_nil
      end
    end

    describe 'when scoped with a condition other than eql' do
      before :all do
        @articles = @articles.all(:content.not => 'Sample')

        @return = @resource = @articles.new
      end

      it 'should return a Resource' do
        @return.should be_kind_of(DataMapper::Resource)
      end

      it 'should be a new Resource' do
        @resource.should be_new
      end

      it 'should append the Resource to the Collection' do
        @articles.last.should equal(@resource)
      end

      it 'should not use the query conditions to set default values' do
        @resource.content.should be_nil
      end
    end
  end

  it { should respond_to(:pop) }

  describe '#pop' do
    before :all do
      @new = @articles.create(:title => 'Sample Article')  # TODO: freeze @new
    end

    describe 'with no arguments' do
      before :all do
        @return = @articles.pop
      end

      it 'should return a Resource' do
        @return.should be_kind_of(DataMapper::Resource)
      end

      it 'should be the last Resource in the Collection' do
        @return.should == @new
      end

      it 'should remove the Resource from the Collection' do
        @articles.should_not be_include(@new)
      end
    end

    if RUBY_VERSION >= '1.8.7'
      describe 'with a limit specified' do
        before :all do
          @return = @articles.pop(1)
        end

        it 'should return an Array' do
          @return.should be_kind_of(Array)
        end

        it 'should return the expected Resources' do
          @return.should == [ @new ]
        end

        it 'should remove the Resource from the Collection' do
          @articles.should_not be_include(@new)
        end
      end
    end
  end

  it { should respond_to(:push) }

  describe '#push' do
    before :all do
      @resources = [ @article_model.new(:title => 'Title 1'), @article_model.new(:title => 'Title 2') ]

      @return = @articles.push(*@resources)
    end

    it 'should return a Collection' do
      @return.should be_kind_of(DataMapper::Collection)
    end

    it 'should return self' do
      @return.should equal(@articles)
    end

    it 'should append the Resources to the Collection' do
      @articles.should == [ @article ] + @resources
    end
  end

  it { should respond_to(:reject!) }

  describe '#reject!' do
    describe 'with a block that matches a Resource in the Collection' do
      before :all do
        @resources = @articles.dup.entries

        @return = @articles.reject! { true }
      end

      it 'should return a Collection' do
        @return.should be_kind_of(DataMapper::Collection)
      end

      it 'should return self' do
        @return.should equal(@articles)
      end

      it 'should remove the Resources from the Collection' do
        @resources.each { |resource| @articles.should_not be_include(resource) }
      end
    end

    describe 'with a block that does not match a Resource in the Collection' do
      before :all do
        @resources = @articles.dup.entries

        @return = @articles.reject! { false }
      end

      it 'should return nil' do
        @return.should be_nil
      end

      it 'should not modify the Collection' do
        @articles.should == @resources
      end
    end
  end

  it { should respond_to(:reload) }

  describe '#reload' do
    describe 'with no arguments' do
      before :all do
        @resources = @articles.dup.entries

        @return = @collection = @articles.reload
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

      it 'should return self' do
        @return.should equal(@articles)
      end

      { :title => true, :content => false }.each do |attribute, expected|
        it "should have query field #{attribute.inspect} #{'not' unless expected} loaded".squeeze(' ') do
          @collection.each { |resource| resource.attribute_loaded?(attribute).should == expected }
        end
      end
    end

    describe 'with a Hash query' do
      before :all do
        @resources = @articles.dup.entries

        @return = @collection = @articles.reload(:fields => [ :content ])  # :title is a default field
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

      it 'should return self' do
        @return.should equal(@articles)
      end

      [ :id, :content, :title ].each do |attribute|
        it "should have query field #{attribute.inspect} loaded" do
          @collection.each { |resource| resource.attribute_loaded?(attribute).should be_true }
        end
      end
    end

    describe 'with a Query' do
      before :all do
        @query = DataMapper::Query.new(@repository, @article_model, :fields => [ :content ])  # :title is an original field

        @return = @collection = @articles.reload(@query)
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

      it 'should return self' do
        @return.should equal(@articles)
      end

      [ :id, :content, :title ].each do |attribute|
        it "should have query field #{attribute.inspect} loaded" do
          @collection.each { |resource| resource.attribute_loaded?(attribute).should be_true }
        end
      end
    end
  end

  it { should respond_to(:replace) }

  describe '#replace' do
    describe 'when provided an Array of Resources' do
      before :all do
        @resources = @articles.dup.entries

        @return = @articles.replace(@other_articles)
      end

      it 'should return a Collection' do
        @return.should be_kind_of(DataMapper::Collection)
      end

      it 'should return self' do
        @return.should equal(@articles)
      end

      it 'should update the Collection with new Resources' do
        @articles.should == @other_articles
      end
    end

    describe 'when provided an Array of Hashes' do
      before :all do
        @array = [ { :content => 'From Hash' } ].freeze

        @return = @articles.replace(@array)
      end

      it 'should return a Collection' do
        @return.should be_kind_of(DataMapper::Collection)
      end

      it 'should return self' do
        @return.should equal(@articles)
      end

      it 'should initialize a Resource' do
        @return.first.should be_kind_of(DataMapper::Resource)
      end

      it 'should be a new Resource' do
        @return.first.should be_new
      end

      it 'should be a Resource with attributes matching the Hash' do
        @return.first.attributes.only(*@array.first.keys).should == @array.first
      end
    end
  end

  it { should respond_to(:reverse!) }

  describe '#reverse!' do
    before :all do
      @query = @articles.query

      @new = @articles.create(:title => 'Sample Article')

      @return = @articles.reverse!
    end

    it 'should return a Collection' do
      @return.should be_kind_of(DataMapper::Collection)
    end

    it 'should return self' do
      @return.should equal(@articles)
    end

    it 'should return a Collection with reversed entries' do
      @return.should == [ @new, @article ]
    end

    it 'should return a Query that equal to the original' do
      @return.query.should equal(@query)
    end
  end

  [ :save, :save! ].each do |method|
    it { should respond_to(method) }

    describe "##{method}" do
      describe 'when Resources are not saved' do
        before :all do
          @articles.new(:title => 'New Article', :content => 'New Article')

          @return = @articles.send(method)
        end

        it 'should return true' do
          @return.should be_true
        end

        it 'should save each Resource' do
          @articles.each { |resource| resource.should be_saved }
        end
      end

      describe 'when Resources have been orphaned' do
        before :all do
          @resources = @articles.entries
          @articles.replace([])

          @return = @articles.send(method)
        end

        it 'should return true' do
          @return.should be_true
        end
      end
    end
  end

  it { should respond_to(:shift) }

  describe '#shift' do
    describe 'with no arguments' do
      before :all do
        @return = @articles.shift
      end

      it 'should return a Resource' do
        @return.should be_kind_of(DataMapper::Resource)
      end

      it 'should be the first Resource in the Collection' do
        @return.key.should == @article.key
      end

      it 'should remove the Resource from the Collection' do
        @articles.should_not be_include(@return)
      end
    end

    if RUBY_VERSION >= '1.8.7'
      describe 'with a limit specified' do
        before :all do
          @return = @articles.shift(1)
        end

        it 'should return an Array' do
          @return.should be_kind_of(Array)
        end

        it 'should return the expected Resources' do
          @return.size.should == 1
          @return.first.key.should == @article.key
        end

        it 'should remove the Resource from the Collection' do
          @articles.should_not be_include(@article)
        end
      end
    end
  end

  it { should respond_to(:slice!) }

  describe '#slice!' do
    before :all do
      1.upto(10) { |number| @articles.create(:content => "Article #{number}") }

      @copy = @articles.dup
    end

    describe 'with a positive offset' do
      before :all do
        unless @skip
          @return = @resource = @articles.slice!(0)
        end
      end

      it 'should return a Resource' do
        @return.should be_kind_of(DataMapper::Resource)
      end

      it 'should return expected Resource' do
        @return.key.should == @article.key
      end

      it 'should return the same as Array#slice!' do
        @return.should == @copy.entries.slice!(0)
      end

      it 'should remove the Resource from the Collection' do
        @articles.should_not be_include(@resource)
      end
    end

    describe 'with a positive offset and length' do
      before :all do
        unless @skip
          @return = @resources = @articles.slice!(5, 5)
        end
      end

      it 'should return a Collection' do
        @return.should be_kind_of(DataMapper::Collection)
      end

      it 'should return the expected Resource' do
        @return.should == @copy.entries.slice!(5, 5)
      end

      it 'should remove the Resources from the Collection' do
        @resources.each { |resource| @articles.should_not be_include(resource) }
      end

      it 'should scope the Collection' do
        @resources.reload.should == @copy.entries.slice!(5, 5)
      end
    end

    describe 'with a positive range' do
      before :all do
        unless @skip
          @return = @resources = @articles.slice!(5..10)
        end
      end

      it 'should return a Collection' do
        @return.should be_kind_of(DataMapper::Collection)
      end

      it 'should return the expected Resources' do
        @return.should == @copy.entries.slice!(5..10)
      end

      it 'should remove the Resources from the Collection' do
        @resources.each { |resource| @articles.should_not be_include(resource) }
      end

      it 'should scope the Collection' do
        @resources.reload.should == @copy.entries.slice!(5..10)
      end
    end

    describe 'with a negative offset' do
      before :all do
        unless @skip
          @return = @resource = @articles.slice!(-1)
        end
      end

      it 'should return a Resource' do
        @return.should be_kind_of(DataMapper::Resource)
      end

      it 'should return expected Resource' do
        @return.should == @copy.entries.slice!(-1)
      end

      it 'should remove the Resource from the Collection' do
        @articles.should_not be_include(@resource)
      end
    end

    describe 'with a negative offset and length' do
      before :all do
        unless @skip
          @return = @resources = @articles.slice!(-5, 5)
        end
      end

      it 'should return a Collection' do
        @return.should be_kind_of(DataMapper::Collection)
      end

      it 'should return the expected Resources' do
        @return.should == @copy.entries.slice!(-5, 5)
      end

      it 'should remove the Resources from the Collection' do
        @resources.each { |resource| @articles.should_not be_include(resource) }
      end

      it 'should scope the Collection' do
        @resources.reload.should == @copy.entries.slice!(-5, 5)
      end
    end

    describe 'with a negative range' do
      before :all do
        unless @skip
          @return = @resources = @articles.slice!(-3..-2)
        end
      end

      it 'should return a Collection' do
        @return.should be_kind_of(DataMapper::Collection)
      end

      it 'should return the expected Resources' do
        @return.should == @copy.entries.slice!(-3..-2)
      end

      it 'should remove the Resources from the Collection' do
        @resources.each { |resource| @articles.should_not be_include(resource) }
      end

      it 'should scope the Collection' do
        @resources.reload.should == @copy.entries.slice!(-3..-2)
      end
    end

    describe 'with an offset not within the Collection' do
      before :all do
        unless @skip
          @return = @articles.slice!(12)
        end
      end

      it 'should return nil' do
        @return.should be_nil
      end
    end

    describe 'with an offset and length not within the Collection' do
      before :all do
        unless @skip
          @return = @articles.slice!(12, 1)
        end
      end

      it 'should return nil' do
        @return.should be_nil
      end
    end

    describe 'with a range not within the Collection' do
      before :all do
        unless @skip
          @return = @articles.slice!(12..13)
        end
      end

      it 'should return nil' do
        @return.should be_nil
      end
    end
  end

  it { should respond_to(:sort!) }

  describe '#sort!' do
    describe 'without a block' do
      before :all do
        @return = @articles.unshift(@other).sort!
      end

      it 'should return a Collection' do
        @return.should be_kind_of(DataMapper::Collection)
      end

      it 'should return self' do
        @return.should equal(@articles)
      end

      it 'should modify and sort the Collection using default sort order' do
        @articles.should == [ @article, @other ]
      end
    end

    describe 'with a block' do
      before :all do
        @return = @articles.unshift(@other).sort! { |a_resource, b_resource| b_resource.id <=> a_resource.id }
      end

      it 'should return a Collection' do
        @return.should be_kind_of(DataMapper::Collection)
      end

      it 'should return self' do
        @return.should equal(@articles)
      end

      it 'should modify and sort the Collection using supplied block' do
        @articles.should == [ @other, @article ]
      end
    end
  end

  [ :splice, :[]= ].each do |method|
    it { should respond_to(method) }

    describe "##{method}" do
      before :all do
        unless @skip
          orphans = (1..10).map do |number|
            articles = @articles.dup
            articles.create(:content => "Article #{number}")
            articles.pop  # remove the article from the tail
          end

          @articles.unshift(*orphans.first(5))
          @articles.concat(orphans.last(5))

          unless loaded
            @articles.should_not be_loaded
          end

          @copy = @articles.dup
          @new = @article_model.new(:content => 'New Article')
        end
      end

      describe 'with a positive offset and a Resource' do
        before :all do
          rescue_if @skip do
            @original = @copy[1]

            @return = @resource = @articles.send(method, 1, @new)
          end
        end

        should_not_be_a_kicker

        it 'should return a Resource' do
          @return.should be_kind_of(DataMapper::Resource)
        end

        it 'should return expected Resource' do
          @return.should equal(@new)
        end

        it 'should return the same as Array#[]=' do
          @return.should == @copy.entries[1] = @new
        end

        it 'should include the Resource in the Collection' do
          @articles.should be_include(@resource)
        end
      end

      describe 'with a positive offset and length and a Resource' do
        before :all do
          rescue_if @skip do
            @original = @copy[2]

            @return = @resource = @articles.send(method, 2, 1, @new)
          end
        end

        should_not_be_a_kicker

        it 'should return a Resource' do
          @return.should be_kind_of(DataMapper::Resource)
        end

        it 'should return the expected Resource' do
          @return.should equal(@new)
        end

        it 'should return the same as Array#[]=' do
          @return.should == @copy.entries[2, 1] = @new
        end

        it 'should include the Resource in the Collection' do
          @articles.should be_include(@resource)
        end
      end

      describe 'with a positive range and a Resource' do
        before :all do
          rescue_if @skip do
            @originals = @copy.values_at(2..3)

            @return = @resource = @articles.send(method, 2..3, @new)
          end
        end

        should_not_be_a_kicker

        it 'should return a Resource' do
          @return.should be_kind_of(DataMapper::Resource)
        end

        it 'should return the expected Resources' do
            @return.should equal(@new)
        end

        it 'should return the same as Array#[]=' do
          @return.should == @copy.entries[2..3] = @new
        end

        it 'should include the Resource in the Collection' do
          @articles.should be_include(@resource)
        end
      end

      describe 'with a negative offset and a Resource' do
        before :all do
          rescue_if @skip do
            @original = @copy[-1]

            @return = @resource = @articles.send(method, -1, @new)
          end
        end

        should_not_be_a_kicker

        it 'should return a Resource' do
          @return.should be_kind_of(DataMapper::Resource)
        end

        it 'should return expected Resource' do
          @return.should equal(@new)
        end

        it 'should return the same as Array#[]=' do
          @return.should == @copy.entries[-1] = @new
        end

        it 'should include the Resource in the Collection' do
          @articles.should be_include(@resource)
        end
      end

      describe 'with a negative offset and length and a Resource' do
        before :all do
          rescue_if @skip do
            @original = @copy[-2]

            @return = @resource = @articles.send(method, -2, 1, @new)
          end
        end

        should_not_be_a_kicker

        it 'should return a Resource' do
          @return.should be_kind_of(DataMapper::Resource)
        end

        it 'should return the expected Resource' do
          @return.should equal(@new)
        end

        it 'should return the same as Array#[]=' do
          @return.should == @copy.entries[-2, 1] = @new
        end

        it 'should include the Resource in the Collection' do
          @articles.should be_include(@resource)
        end
      end

      describe 'with a negative range and a Resource' do
        before :all do
          rescue_if @skip do
            @originals = @articles.values_at(-3..-2)

            @return = @resource = @articles.send(method, -3..-2, @new)
          end
        end

        should_not_be_a_kicker

        it 'should return a Resource' do
          @return.should be_kind_of(DataMapper::Resource)
        end

        it 'should return the expected Resources' do
          @return.should equal(@new)
        end

        it 'should return the same as Array#[]=' do
          @return.should == @copy.entries[-3..-2] = @new
        end

        it 'should include the Resource in the Collection' do
          @articles.should be_include(@resource)
        end
      end
    end
  end

  describe '#[]=' do
    describe 'when swapping resources' do
      before :all do
        rescue_if @skip do
          @articles.create(:content => 'Another Article')

          @entries = @articles.entries

          @articles[0], @articles[1] = @articles[1], @articles[0]
        end
      end

      it 'should include the Resource in the Collection' do
        @articles.should == @entries.reverse
      end
    end
  end

  [ :union, :|, :+ ].each do |method|
    it { should respond_to(method) }

    describe "##{method}" do
      subject { @articles.send(method, @other_articles) }

      describe 'with a Collection' do
        it { should be_kind_of(DataMapper::Collection) }

        it { should == [ @article, @other ] }

        it { subject.query.should == @articles.query.union(@other_articles.query) }

        it { should == @articles.to_a | @other_articles.to_a }
      end

      describe 'with an Array' do
        before { @other_articles = @other_articles.to_ary }

        it { should be_kind_of(DataMapper::Collection) }

        it { should == [ @article, @other ] }

        it { should == @articles.to_a | @other_articles.to_a }
      end

      describe 'with a Set' do
        before { @other_articles = @other_articles.to_set }

        it { should be_kind_of(DataMapper::Collection) }

        it { should == [ @article, @other ] }

        it { should == @articles.to_a | @other_articles.to_a }
      end
    end
  end

  it { should respond_to(:unshift) }

  describe '#unshift' do
    before :all do
      @resources = [ @article_model.new(:title => 'Title 1'), @article_model.new(:title => 'Title 2') ]

      @return = @articles.unshift(*@resources)
    end

    it 'should return a Collection' do
      @return.should be_kind_of(DataMapper::Collection)
    end

    it 'should return self' do
      @return.should equal(@articles)
    end

    it 'should prepend the Resources to the Collection' do
      @articles.should == @resources + [ @article ]
    end
  end

  [ :update, :update! ].each do |method|
    it { should respond_to(method) }

    describe "##{method}" do
      describe 'with no arguments' do
        before :all do
          @return = @articles.send(method)
        end

        if method == :update!
          should_not_be_a_kicker
        end

        it 'should return true' do
          @return.should be_true
        end
      end

      describe 'with attributes' do
        before :all do
          @attributes = { :title => 'Updated Title' }

          @return = @articles.send(method, @attributes)
        end

        if method == :update!
          should_not_be_a_kicker
        end

        it 'should return true' do
          @return.should be_true
        end

        it 'should update attributes of all Resources' do
          @articles.each { |resource| @attributes.each { |key, value| resource.__send__(key).should == value } }
        end

        it 'should persist the changes' do
          resource = @article_model.get(*@article.key)
          @attributes.each { |key, value| resource.__send__(key).should == value }
        end
      end

      describe 'with attributes where one is a parent association' do
        before :all do
          @attributes = { :original => @other }

          @return = @articles.send(method, @attributes)
        end

        if method == :update!
          should_not_be_a_kicker
        end

        it 'should return true' do
          @return.should be_true
        end

        it 'should update attributes of all Resources' do
          @articles.each { |resource| @attributes.each { |key, value| resource.__send__(key).should == value } }
        end

        it 'should persist the changes' do
          resource = @article_model.get(*@article.key)
          @attributes.each { |key, value| resource.__send__(key).should == value }
        end
      end

      describe 'with attributes where a required property is nil' do
        before :all do
          @return = @articles.send(method, :title => nil)
        end

        if method == :update!
          should_not_be_a_kicker
        end

        it 'should return false' do
          @return.should be_false
        end
      end

      describe 'on a limited collection' do
        before :all do
          @other      = @articles.create
          @limited    = @articles.all(:limit => 1)
          @attributes = { :content => 'Updated Content' }

          @return = @limited.send(method, @attributes)
        end

        if method == :update!
          should_not_be_a_kicker(:@limited)
        end

        it 'should return true' do
          @return.should be_true
        end

        it 'should bypass validation' do
          pending 'TODO: not sure how to best spec this'
        end

        it 'should update attributes of all Resources' do
          @limited.each { |resource| @attributes.each { |key, value| resource.__send__(key).should == value } }
        end

        it 'should persist the changes' do
          resource = @article_model.get(*@article.key)
          @attributes.each { |key, value| resource.__send__(key).should == value }
        end

        it 'should not update the other Resource' do
          @other.reload
          @attributes.each { |key, value| @other.__send__(key).should_not == value }
        end
      end

      describe 'on a dirty collection' do
        before :all do
          @articles.each { |r| r.content = 'Changed' }
        end

        it 'should raise an exception' do
          lambda {
            @articles.send(method, :content => 'New Content')
          }.should raise_error(DataMapper::UpdateConflictError, "#{@articles.class}##{method} cannot be called on a dirty collection")
        end
      end
    end
  end

  it 'should respond to a public model method with #method_missing' do
    @articles.should respond_to(:base_model)
  end

  describe '#method_missing' do
    describe 'with a public model method' do
      before :all do
        @return = @articles.model.base_model
      end

      should_not_be_a_kicker

      it 'should return expected object' do
        @return.should == @article_model
      end
    end
  end
end
