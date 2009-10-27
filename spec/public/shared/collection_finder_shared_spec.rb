share_examples_for 'Collection Finder Interface' do
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

  describe '#at' do
    before :all do
      @copy = @articles.dup
      @copy.to_a
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
    end
  end

  describe '#first' do
    before :all do
      1.upto(5) { |number| @articles.create(:content => "Article #{number}") }

      @copy = @articles.dup
      @copy.to_a

      # reload the articles
      @articles = @article_model.all(@articles.query)
    end

    describe 'with no arguments' do
      before :all do
        @return = @resource = @articles.first
      end

      it 'should return a Resource' do
        @return.should be_kind_of(DataMapper::Resource)
      end

      it 'should be first Resource in the Collection' do
        @resource.should equal(@copy.entries.first)
      end

      it 'should return the same Resource every time' do
        @return.should equal(@articles.first)
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
    end

    describe 'with a limit specified', 'after prepending to the collection' do
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
    end
  end

  [ :get, :get! ].each do |method|
    describe 'with a key to a Resource within a Collection using a limit' do
      before :all do
        rescue_if @skip && method == :get! do
          @articles = @articles.all(:limit => 1)

          @return = @resource = @articles.send(method, *@article.key)
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
        rescue_if @skip && method == :get! do
          @new = @articles.create(:content => 'New Article')
          @articles = @articles.all(:offset => 1, :limit => 1)

          @return = @resource = @articles.send(method, *@new.key)
        end
      end

      it 'should return a Resource' do
        @return.should be_kind_of(DataMapper::Resource)
      end

      it 'should be matching Resource in the Collection' do
        @resource.should equal(@new)
      end
    end
  end

  describe '#last' do
    before :all do
      1.upto(5) { |number| @articles.create(:content => "Article #{number}") }

      @copy = @articles.dup
      @copy.to_a

      # reload the articles
      @articles = @article_model.all(@articles.query)
    end

    describe 'with no arguments' do
      before :all do
        @return = @resource = @articles.last
      end

      it 'should return a Resource' do
        @return.should be_kind_of(DataMapper::Resource)
      end

      it 'should be last Resource in the Collection' do
        @resource.should equal(@copy.entries.last)
      end

      it 'should return the same Resource every time' do
        @return.should equal(@articles.last)
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
    end

    describe 'with empty query', 'after appending to the collection' do
      before :all do
        @return = @resource = @articles.push(@other).last({})
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
    end

    describe 'with a limit specified', 'after appending to the collection' do
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
    end
  end
end
