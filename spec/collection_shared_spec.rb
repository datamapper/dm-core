require File.expand_path(File.join(File.dirname(__FILE__), 'spec_helper'))

# TODO: test all instance methods when collection is loaded and not loaded

describe 'A Collection', :shared => true do
  before do
    %w[ @repository @model @other @article @new_article @articles @other_articles ].each do |ivar|
      raise "+#{ivar}+ should be defined in before block" unless instance_variable_get(ivar)
    end
  end

  after do
    @model.all.destroy!
  end

  describe '#<<' do
    it 'should append the resource onto the collection' do
      @articles << @new_article
      @articles.last.should == @new_article
    end

    it 'should relate each new resource to the collection' do
      # resource is orphaned
      @new_article.collection.object_id.should_not == @articles.object_id

      @articles << @new_article

      # resource is related
      @new_article.collection.object_id.should == @articles.object_id
    end

    it 'should return self' do
      @articles.<<(@new_article).object_id.should == @articles.object_id
    end
  end

  describe '#all' do
    describe 'with no arguments' do
      it 'should return self' do
        @articles.object_id.should == @articles.object_id
      end
    end

    describe 'with query arguments' do
      describe 'should return a Collection' do
        before do
          @articles = @articles.all(:limit => 10, :offset => 10)
        end

        it 'has an offset equal to 10' do
          @articles.all.query.offset.should == 10
        end

        it 'has a cumulative offset equal to 11 when passed an offset of 1' do
          @articles.all(:offset => 1).query.offset.should == 11
        end

        it 'has a cumulative offset equal to 19 when passed an offset of 9' do
          @articles.all(:offset => 9).query.offset.should == 19
        end

        it 'is empty when passed an offset that is out of range' do
          pending do
            empty_collection = @articles.all(:offset => 10)
            empty_collection.should == []
            empty_collection.should be_loaded
          end
        end

        it 'has an limit equal to 10' do
          @articles.all.query.limit.should == 10
        end

        it 'has a limit equal to 5' do
          @articles.all(:limit => 5).query.limit.should == 5
        end

        it 'has a limit equal to 10 if passed a limit greater than 10' do
          @articles.all(:limit => 11).query.limit.should == 10
        end

        describe 'limitless collections' do
          before do
            query = DataMapper::Query.new(@repository, @model)
            @unlimited = DataMapper::Collection.new(query) {}
          end

          it 'has a nil limit' do
            @unlimited.query.limit.should be_nil
          end

          it 'has a limit equal to 1000 when passed a limit of 1000' do
            @unlimited.all(:limit => 1000).query.limit.should == 1000
          end
        end
      end
    end
  end

  describe '#at' do
    it 'should return the resource by offset' do
      @articles.at(0).id.should == @article.id
    end

    it 'should return a Resource' do
      @articles.at(0).should be_kind_of(DataMapper::Resource)
    end

    it 'should return a Resource when using a negative index' do
      article_at = @articles.at(-1)
      article_at.should be_kind_of(DataMapper::Resource)
      article_at.id.should == @article.id
    end
  end

  describe '#build' do
    it 'should build a new resource' do
      article = @articles.build(@new_article.attributes)
      article.should be_kind_of(@model)
      article.should be_new_record
    end

    it 'should append the new resource to the collection' do
      article = @articles.build(@new_article.attributes)
      article.should be_new_record
      article.collection.object_id.should == @articles.object_id
      @articles.should include(article)
    end

    it 'should use the query conditions to set default values' do
      @articles.query.update(@new_article.attributes)

      article = @articles.build
      article.attributes.except(:site_id).should == @new_article.attributes.except(:site_id)
    end
  end

  describe '#clear' do
    it 'should make the collection empty' do
      @articles.should_not be_empty
      @articles.clear
      @articles.should be_empty
    end

    it 'should orphan the resource from the collection' do
      entries = @articles.entries

      # resources are related
      entries.each { |r| r.collection.object_id.should == @articles.object_id }

      @articles.clear

      # resources are orphaned
      entries.each { |r| r.collection.object_id.should_not == @articles.object_id }
    end

    it 'should return self' do
      @articles.clear.object_id.should == @articles.object_id
    end
  end

  describe '#collect!' do
    it 'should update the collection inline' do
      @articles.collect! { |article| :other_value }.should == [ :other_value ]
    end

    it 'should return self' do
      @articles.collect! { |article| article }.object_id.should == @articles.object_id
    end
  end

  describe '#concat' do
    it 'should concatenate the two collections' do
      @articles.concat(@other_articles).should == [ @article, @other ]
    end

    it 'should return self' do
      @articles.concat(@other_articles).object_id.should == @articles.object_id
    end
  end

  describe '#create' do
    it 'should create a new resource' do
      article = @articles.create(@new_article.attributes)
      article.should be_kind_of(@model)
      article.should_not be_new_record
    end

    it 'should append the new resource to the collection' do
      article = @articles.create(@new_article.attributes)
      article.should_not be_new_record
      article.collection.object_id.should == @articles.object_id
      @articles.should include(article)
    end

# TODO: refactor to not use mocks
#    it 'should not append the resource if it was not saved' do
#      @repository.should_receive(:create).and_return(false)
#      @model.should_receive(:repository).at_least(:once).and_return(@repository)
#
#      article = @articles.create
#      article.should be_new_record
#
#      article.collection.object_id.should_not == @articles.object_id
#      @articles.should_not include(article)
#    end

    it 'should use the query conditions to set default values' do
      @articles.query.update(@new_article.attributes)

      article = @articles.create
      article.attributes.except(:id, :site_id).should == @new_article.attributes.except(:id, :site_id)
    end
  end

  describe '#delete' do
    it 'should delete the matching resource' do
      @articles.should have(1).entries
      @articles.delete(@article)
      @articles.should be_empty
    end

    it 'should orphan the resource from the collection' do
      articles = @article.collection
      articles.delete(@article)
      @article.collection.object_id.should_not == articles.object_id
    end

    it 'should return a Resource' do
      article = @articles.delete(@article)

      article.should be_kind_of(DataMapper::Resource)
      article.object_id.should == @article.object_id
    end
  end

  describe '#delete_at' do
    it 'should delete the resource by index' do
      @articles.should have(1).entries
      @articles.delete_at(0)
      @articles.should be_empty
    end

    it 'should orphan the resource from the collection' do
      articles = @article.collection
      articles.delete_at(0)
      @article.collection.object_id.should_not == articles.object_id
    end

    it 'should return a Resource' do
      articles = @article.collection

      article = articles.delete_at(0)

      article.should be_kind_of(DataMapper::Resource)
      article.object_id.should == @article.object_id
    end
  end

  describe '#destroy!' do
    before do
      @titles = [ @article.title ]
    end

    it 'should destroy the resources in the collection' do
      @articles.map { |r| r.id }.should == @titles
      @articles.destroy!
      @model.all(:title => @titles).should == []
    end

    it 'should clear the collection' do
      @articles.map { |r| r.id }.should == @titles
      @articles.destroy!
      @articles.should == []
    end

    it 'should return true if successful' do
      @articles.destroy!.should == true
    end
  end

  describe '#each' do
    it 'should yield to each resource in the collection' do
      articles = []
      @articles.each { |article| articles << article }
      articles.should == @articles
    end

    it 'should return self' do
      @articles.each { |article| }.object_id.should == @articles.object_id
    end
  end

  describe '#each_index' do
    it 'should yield to the index of each resource in the collection' do
      indexes = []
      @articles.each_index { |index| indexes << index }
      indexes.should == [ 0 ]
    end

    it 'should return self' do
      @articles.each_index { |index| }.object_id.should == @articles.object_id
    end
  end

  describe '#eql?' do
    it 'should return true if for the same collection' do
      @articles.object_id.should == @articles.object_id
      @articles.should be_eql(@articles)
    end

    it 'should return true for duplicate collections' do
      dup = @articles.dup
      dup.object_id.should_not == @articles.object_id
      dup.should be_eql(@articles)
    end

    it 'should return false for different collections' do
      @articles.should_not be_eql(@other_articles)
    end
  end

  describe '#fetch' do
    it 'should return the expected resource' do
      @articles.fetch(0).should == @article
    end

    it 'should return a Resource' do
      @articles.fetch(0).should be_kind_of(DataMapper::Resource)
    end
  end

  describe '#first' do
    describe 'with no arguments' do
      it 'should return the first resource' do
        @articles.first.id.should == @article.id
      end

      it 'should return a Resource' do
        @articles.first.should be_kind_of(DataMapper::Resource)
      end
    end

    describe 'with limit specified' do
      it 'should return the first N resources' do
        @articles.first(1).should == [ @article ]
      end

      it 'should order based on the model defaults' do
        order = @articles.first(1).query.order
        order.size.should == 1
        order.first.property.should == @model.properties[:title]
        order.first.direction.should == :asc
      end

      it 'should return a Collection' do
        @articles.first(1).should be_kind_of(DataMapper::Collection)
      end
    end
  end

  describe '#freeze' do
    it 'should freeze the collection' do
      @articles.should_not be_frozen
      @articles.freeze
      @articles.should be_frozen
    end
  end

#  describe '#get' do
#    it 'should find a resource in a collection by key' do
#      article = @articles.get(*@new_article.key)
#      article.should be_kind_of(DataMapper::Resource)
#      article.id.should == @new_article.id
#    end
#
#    it "should find a resource in a collection by typecasting the key" do
#      article = @articles.get(@new_article.key.to_s)
#      article.should be_kind_of(DataMapper::Resource)
#      article.id.should == @new_article.id
#    end
#
#    it 'should not find a resource not in the collection' do
#      @query.update(:offset => 0, :limit => 3)
#      @david = Zebra.create(:name => 'David', :age => 15,  :notes => 'Albino')
#      @articles.get(@david.key).should be_nil
#    end
#  end
#
#  describe '#get!' do
#    it 'should find a resource in a collection by key' do
#      article = @articles.get!(*@new_article.key)
#      article.should be_kind_of(DataMapper::Resource)
#      article.id.should == @new_article.id
#    end
#
#    it 'should raise an exception if the resource is not found' do
#      @query.update(:offset => 0, :limit => 3)
#      @david = Zebra.create(:name => 'David', :age => 15,  :notes => 'Albino')
#      lambda {
#        @articles.get!(@david.key)
#      }.should raise_error(DataMapper::ObjectNotFoundError)
#    end
#  end
#
#  describe '#insert' do
#    it 'should return self' do
#      @articles.insert(1, @steve).object_id.should == @articles.object_id
#    end
#  end
#
#  describe '#last' do
#    describe 'with no arguments' do
#      it 'should return a Resource' do
#        last = @articles.last
#        last.should_not be_nil
#        last.should be_kind_of(DataMapper::Resource)
#        last.id.should == @steve.id
#      end
#    end
#
#    describe 'with limit specified' do
#      it 'should return a Collection' do
#        collection = @articles.last(2)
#
#        collection.should be_kind_of(DataMapper::Collection)
#        collection.object_id.should_not == @articles.object_id
#
#        collection.query.order.size.should == 1
#        collection.query.order.first.property.should == @model.properties[:id]
#        collection.query.order.first.direction.should == :desc
#
#        collection.query.offset.should == 0
#        collection.query.limit.should == 2
#
#        collection.length.should == 2
#
#        collection.entries.map { |r| r.id }.should == [ @bessie.id, @steve.id ]
#      end
#
#      it 'should return a Collection if limit is 1' do
#        collection = @articles.last(1)
#
#        collection.class.should == DataMapper::Collection  # should be_kind_of(DataMapper::Collection)
#        collection.object_id.should_not == @articles.object_id
#      end
#    end
#  end
#
#  describe '#load' do
#    it 'should load resources from the identity map when possible' do
#      @steve.collection = nil
#      @repository.identity_map(@model).should_receive(:get).with([ @steve.id ]).and_return(@steve)
#
#      collection = @repository.read_many(@query.merge(:id => @steve.id))
#
#      collection.size.should == 1
#      collection.map { |r| r.object_id }.should == [ @steve.object_id ]
#
#      @steve.collection.object_id.should == collection.object_id
#    end
#
#    it 'should return a Resource' do
#      @articles.load([ @steve.id, @steve.name, @steve.age ]).should be_kind_of(DataMapper::Resource)
#    end
#  end
#
#  describe '#loaded?' do
#    if loaded
#      it 'should return true for an initialized collection' do
#        @articles.should be_loaded
#      end
#    else
#      it 'should return false for an uninitialized collection' do
#        @articles.should_not be_loaded
#        @articles.to_a  # load collection
#        @articles.should be_loaded
#      end
#    end
#  end
#
#  describe '#pop' do
#    it 'should orphan the resource from the collection' do
#      collection = @steve.collection
#
#      # resource is related
#      @steve.collection.object_id.should == collection.object_id
#
#      collection.should have(1).entries
#      collection.pop.object_id.should == @steve.object_id
#      collection.should be_empty
#
#      # resource is orphaned
#      @steve.collection.object_id.should_not == collection.object_id
#    end
#
#    it 'should return a Resource' do
#      @articles.pop.key.should == @steve.key
#    end
#  end
#
#  describe '#properties' do
#    it 'should return a PropertySet' do
#      @articles.properties.should be_kind_of(DataMapper::PropertySet)
#    end
#
#    it 'should contain same properties as query.fields' do
#      properties = @articles.properties
#      properties.entries.should == @articles.query.fields
#    end
#  end
#
#  describe '#push' do
#    it 'should relate each new resource to the collection' do
#      # resource is orphaned
#      @new_article.collection.object_id.should_not == @articles.object_id
#
#      @articles.push(@new_article)
#
#      # resource is related
#      @new_article.collection.object_id.should == @articles.object_id
#    end
#
#    it 'should return self' do
#      @articles.push(@steve).object_id.should == @articles.object_id
#    end
#  end
#
#  describe '#relationships' do
#    it 'should return a Hash' do
#      @articles.relationships.should be_kind_of(Hash)
#    end
#
#    it 'should contain same properties as query.model.relationships' do
#      relationships = @articles.relationships
#      relationships.should == @articles.query.model.relationships
#    end
#  end
#
#  describe '#reject' do
#    it 'should return a Collection with resources that did not match the block' do
#      rejected = @articles.reject { |article| false }
#      rejected.class.should == Array
#      rejected.should == [ @new_article, @bessie, @steve ]
#    end
#
#    it 'should return an empty Array if resources matched the block' do
#      rejected = @articles.reject { |article| true }
#      rejected.class.should == Array
#      rejected.should == []
#    end
#  end
#
#  describe '#reject!' do
#    it 'should return self if resources matched the block' do
#      @articles.reject! { |article| true }.object_id.should == @articles.object_id
#    end
#
#    it 'should return nil if no resources matched the block' do
#      @articles.reject! { |article| false }.should be_nil
#    end
#  end
#
#  describe '#reload' do
#    it 'should return self' do
#      @articles.reload.object_id.should == @articles.object_id
#    end
#
#    it 'should replace the collection' do
#      original = @articles.dup
#      @articles.reload.should == @articles
#      @articles.should == original
#    end
#
#    it 'should reload lazily initialized fields' do
#      pending 'Move to unit specs'
#
#      @repository.should_receive(:all) do |model,query|
#        model.should == @model
#
#        query.should be_instance_of(DataMapper::Query)
#        query.reload.should     == true
#        query.offset.should     == 0
#        query.limit.should      == 10
#        query.order.should      == []
#        query.fields.should     == @model.properties.defaults
#        query.links.should      == []
#        query.includes.should   == []
#        query.conditions.should == [ [ :eql, @model.properties[:id], [ 1, 2, 3 ] ] ]
#
#        @articles
#      end
#
#      @articles.reload
#    end
#  end
#
#  describe '#replace' do
#    it "should orphan each existing resource from the collection if loaded?" do
#      entries = @articles.entries
#
#      # resources are related
#      entries.each { |r| r.collection.object_id.should == @articles.object_id }
#
#      @articles.should have(3).entries
#      @articles.replace([]).object_id.should == @articles.object_id
#      @articles.should be_empty
#
#      # resources are orphaned
#      entries.each { |r| r.collection.object_id.should_not == @articles.object_id }
#    end
#
#    it 'should relate each new resource to the collection' do
#      # resource is orphaned
#      @new_article.collection.object_id.should_not == @articles.object_id
#
#      @articles.replace([ @new_article ])
#
#      # resource is related
#      @new_article.collection.object_id.should == @articles.object_id
#    end
#
#    it 'should replace the contents of the collection' do
#      other = [ @new_article ]
#      @articles.should_not == other
#      @articles.replace(other)
#      @articles.should == other
#      @articles.object_id.should_not == @other_articles.object_id
#    end
#  end
#
#  describe '#reverse' do
#    [ true, false ].each do |loaded|
#      describe "on a collection where loaded? == #{loaded}" do
#        before do
#          @articles.to_a if loaded
#        end
#
#        it 'should return a Collection with reversed entries' do
#          reversed = @articles.reverse
#          reversed.should be_kind_of(DataMapper::Collection)
#          reversed.object_id.should_not == @articles.object_id
#          reversed.entries.should == @articles.entries.reverse
#
#          reversed.query.order.size.should == 1
#          reversed.query.order.first.property.should == @model.properties[:id]
#          reversed.query.order.first.direction.should == :desc
#        end
#      end
#    end
#  end
#
#  describe '#reverse!' do
#    it 'should return self' do
#      @articles.reverse!.object_id.should == @articles.object_id
#    end
#  end
#
#  describe '#reverse_each' do
#    it 'should return self' do
#      @articles.reverse_each { |article| }.object_id.should == @articles.object_id
#    end
#  end
#
#  describe '#select' do
#    it 'should return an Array with resources that matched the block' do
#      selected = @articles.select { |article| true }
#      selected.class.should == Array
#      selected.should == @articles
#    end
#
#    it 'should return an empty Array if no resources matched the block' do
#      selected = @articles.select { |article| false }
#      selected.class.should == Array
#      selected.should == []
#    end
#  end
#
#  describe '#shift' do
#    it 'should orphan the resource from the collection' do
#      collection = @new_article.collection
#
#      # resource is related
#      @new_article.collection.object_id.should == collection.object_id
#
#      collection.should have(1).entries
#      collection.shift.object_id.should == @new_article.object_id
#      collection.should be_empty
#
#      # resource is orphaned
#      @new_article.collection.object_id.should_not == collection.object_id
#    end
#
#    it 'should return a Resource' do
#      @articles.shift.key.should == @new_article.key
#    end
#  end
#
#  [ :slice, :[] ].each do |method|
#    describe '#slice' do
#      describe 'with an index' do
#        it 'should return a Resource' do
#          resource = @articles.send(method, 0)
#          resource.should be_kind_of(DataMapper::Resource)
#          resource.id.should == @new_article.id
#        end
#      end
#
#      describe 'with a start and length' do
#        it 'should return a Collection' do
#          sliced = @articles.send(method, 0, 1)
#          sliced.should be_kind_of(DataMapper::Collection)
#          sliced.object_id.should_not == @articles.object_id
#          sliced.length.should == 1
#          sliced.map { |r| r.id }.should == [ @new_article.id ]
#        end
#      end
#
#      describe 'with a Range' do
#        it 'should return a Collection' do
#          sliced = @articles.send(method, 0..1)
#          sliced.should be_kind_of(DataMapper::Collection)
#          sliced.object_id.should_not == @articles.object_id
#          sliced.length.should == 2
#          sliced.map { |r| r.id }.should == [ @new_article.id, @bessie.id ]
#        end
#      end
#    end
#  end
#
#  describe '#slice!' do
#    describe 'with an index' do
#      it 'should return a Resource' do
#        resource = @articles.slice!(0)
#        resource.should be_kind_of(DataMapper::Resource)
#      end
#    end
#
#    describe 'with a start and length' do
#      it 'should return an Array' do
#        sliced = @articles.slice!(0, 1)
#        sliced.class.should == Array
#        sliced.map { |r| r.id }.should == [ @new_article.id ]
#      end
#    end
#
#    describe 'with a Range' do
#      it 'should return a Collection' do
#        sliced = @articles.slice(0..1)
#        sliced.should be_kind_of(DataMapper::Collection)
#        sliced.object_id.should_not == @articles.object_id
#        sliced.length.should == 2
#        sliced[0].id.should == @new_article.id
#        sliced[1].id.should == @bessie.id
#      end
#    end
#  end
#
#  describe '#sort' do
#    it 'should return an Array' do
#      sorted = @articles.sort { |a,b| a.age <=> b.age }
#      sorted.class.should == Array
#    end
#  end
#
#  describe '#sort!' do
#    it 'should return self' do
#      @articles.sort! { |a,b| 0 }.object_id.should == @articles.object_id
#    end
#  end
#
#  describe '#unshift' do
#    it 'should relate each new resource to the collection' do
#      # resource is orphaned
#      @new_article.collection.object_id.should_not == @articles.object_id
#
#      @articles.unshift(@new_article)
#
#      # resource is related
#      @new_article.collection.object_id.should == @articles.object_id
#    end
#
#    it 'should return self' do
#      @articles.unshift(@steve).object_id.should == @articles.object_id
#    end
#  end

  describe '#update' do
    it 'should be awesome'
  end

  describe '#update!' do
#    it 'should update the resources in the collection' do
#      pending do
#        # this will not pass with new update!
#        # update! should never loop through and set attributes
#        # even if it is loaded, and it will not reload the
#        # changed objects (even with reload=true, as objects
#        # are created is not in any identity map)
#        names = [ @new_article.name, @bessie.name, @steve.name ]
#        @articles.map { |r| r.name }.should == names
#        @articles.update!(:name => 'John')
#        @articles.map { |r| r.name }.should_not == names
#        @articles.map { |r| r.name }.should == %w[ John ] * 3
#      end
#    end

    it 'should not update loaded resources unless forced' do
      pending 'Fix in-memory adapter to return copies of data'
      @repository.scope do
        articles = @articles.reload
        article  = articles.first

        article.title.should == 'Sample Article'

        articles.update!(:title => 'Updated Article')

        article.title.should == 'Sample Article'
      end
    end

    it 'should update loaded resources if forced' do
      @repository.scope do |r|
        articles = @articles.reload
        article  = @model.first(:title => 'Sample Article')

        articles.update!({ :title => 'Updated Article' }, true)

        article.title.should == 'Updated Article'
      end
    end

    it 'should update collection-query when updating' do
      get_condition = lambda do |collection,name|
        collection.query.conditions.detect { |c| c[0] == :eql && c[1].name == name }[2]
      end

      @repository.scope do
        articles = @articles.all(:title => 'Sample Article')
        get_condition.call(articles, :title).should == 'Sample Article'
        articles.length.should == 1
        articles.update!(:title => 'Updated Article')
        articles.length.should == 1
        get_condition.call(articles, :title).should == 'Updated Article'
      end
    end
  end

#  describe '#keys' do
#    it 'should return a hash of keys' do
#      keys = @articles.send(:keys)
#      keys.length.should == 1
#      keys.each{|property,values| values.should == [1,2,3]}
#    end
#
#    it 'should return an empty hash if collection is empty' do
#      keys = Zebra.all(:id.gt => 10000).send(:keys)
#      keys.should == {}
#    end
#  end
#
#  describe '#values_at' do
#    it 'should return an Array' do
#      values = @articles.values_at(0)
#      values.class.should == Array
#    end
#
#    it 'should return an Array of the resources at the index' do
#      @articles.values_at(0).entries.map { |r| r.id }.should == [ @new_article.id ]
#    end
#  end
end
