require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

# run the specs once with a loaded collection and once not
[ false, true ].each do |loaded|
  describe DataMapper::Collection do
    extend DataMapper::Spec::CollectionHelpers::GroupMethods

    self.loaded = loaded

    before :all do
      class ::Article
        include DataMapper::Resource

        property :id,      Serial
        property :title,   String, :nullable => false
        property :content, Text
        property :author,  String, :nullable => false

        belongs_to :original, :model => self
        has n, :revisions, :model => self, :child_key => [ :original_id ]
        has 1, :previous,  :model => self, :child_key => [ :original_id ], :order => [ :id.desc ]
      end

      @model = Article
    end

    supported_by :all do
      before :all do
        @author = 'Dan Kubb'

        @original = @model.create(:title => 'Original Article',                                               :author => @author)
        @article  = @model.create(:title => 'Sample Article',   :content => 'Sample', :original => @original, :author => @author)
        @other    = @model.create(:title => 'Other Article',    :content => 'Other',                          :author => @author)

        # load the targets without references to a single source
        load_collection = lambda do |query|
          @model.all(query)
        end

        @articles       = load_collection.call(:title => 'Sample Article', :author => @author)
        @other_articles = load_collection.call(:title => 'Other Article',  :author => @author)

        @articles.entries if loaded
      end

      it_should_behave_like 'A public Collection'
#      it_should_behave_like 'A Collection supporting Strategic Eager Loading'
    end
  end
end
