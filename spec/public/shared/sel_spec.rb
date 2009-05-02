share_examples_for 'A Collection supporting Strategic Eager Loading' do
  describe 'using SEL when looping within a loop' do
    before :all do
      @one_to_many = @articles.kind_of?(DataMapper::Associations::OneToMany::Collection)
    end

    before :all do
      @revision = @article.revisions.create(:title => 'Revision')

      @new_article  = @model.create(:title => 'Sample Article')
      @new_revision = @new_article.revisions.create(:title => 'New Revision')
    end

    before :all do
      @original_adapter = @adapter

      @adapter.meta_class.class_eval do
        def eql?(other)
          super || self == other
        end
      end

      @adapter = DataMapper::Repository.adapters[@adapter.name] = CounterAdapter.new(@adapter)
      @repository.instance_variable_set(:@adapter, @adapter)
    end

    before :all do
      @results = []

      @articles.each do |article|
        article.revisions.each do |revision|
          @results << [ article, revision ]
        end
      end
    end

    after :all do
      @adapter = @original_adapter
    end

    it "should only execute the Adapter#read #{loaded ? 'once' : 'twice'}" do
      @adapter.counts[:read].should == (loaded ? 1 : 2)
    end

    it 'should return the expected results' do
      # if the collection is already loaded, then when it iterates it will
      # not know about the newly added articles and their revisions
      if loaded
        @results.should == [ [ @article, @revision ] ]
      else
        pending_if 'TODO: make method_missing not a kicker', @one_to_many do
          @results.should == [ [ @article, @revision ], [ @new_article, @new_revision ] ]
        end
      end
    end
  end
end

share_examples_for 'A Resource supporting Strategic Eager Loading' do
  describe 'using SEL when inside a Collection' do
    before :all do
      @referrer = User.create(:name => 'Referrer')

      @user.update(:referrer => @referrer)

      @new_user = @model.create(:name => 'Another User', :referrer => @referrer)
    end

    before :all do
      @original_adapter = @adapter

      @adapter.meta_class.class_eval do
        def eql?(other)
          super || other == self
        end
      end

      @adapter = DataMapper::Repository.adapters[@adapter.name] = CounterAdapter.new(@adapter)
      @repository.instance_variable_set(:@adapter, @adapter)
    end

    before :all do
      @results = []

      @model.all.each do |user|
        @results << [ user, user.referrer ]
      end

      # some storage engines return the data in a different order
      @results.sort!
    end

    after :all do
      @adapter = @original_adapter
    end

    it 'should only execute the Adapter#read twice' do
      @adapter.counts[:read].should == 2
    end

    it 'should return the expected results' do
      # results are ordered alphabetically by the User name
      @results.should == [ [ @new_user, @referrer ], [ @referrer, nil ], [ @user, @referrer ] ]
    end
  end
end
