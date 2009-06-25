share_examples_for 'A Collection supporting Strategic Eager Loading' do
  describe 'using SEL when looping within a loop' do
    before :all do
      @many_to_many = @articles.kind_of?(DataMapper::Associations::ManyToMany::Collection)
    end

    before :all do
      attributes = {}

      unless @many_to_many
        attributes[:author] = @author
      end

      @revision = @article.revisions.create(attributes.merge(:title => 'Revision'))

      @new_article  = @article_model.create(attributes.merge(:title => 'Sample Article'))
      @new_revision = @new_article.revisions.create(attributes.merge(:title => 'New Revision'))
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
        pending_if 'TODO: make m:m not kick when delegating to the relationship', @many_to_many do
          @results.should == [ [ @article, @revision ], [ @new_article, @new_revision ] ]
        end
      end
    end
  end
end

share_examples_for 'A Resource supporting Strategic Eager Loading' do
  describe 'using SEL when inside a Collection' do
    before :all do
      @referrer = @user_model.create(:name => 'Referrer', :comment => @comment)

      @user.update(:referrer => @referrer)

      @new_user = @user_model.create(:name => 'Another User', :referrer => @referrer, :comment => @comment)
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

      @user_model.all.each do |user|
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
