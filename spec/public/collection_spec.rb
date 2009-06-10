require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

# run the specs once with a loaded collection and once not
[ false, true ].each do |loaded|
  describe DataMapper::Collection do
    extend DataMapper::Spec::CollectionHelpers::GroupMethods

    self.loaded = loaded

    before :all do
      module ::Blog
        class Article
          include DataMapper::Resource

          property :id,      Serial
          property :title,   String, :nullable => false
          property :content, Text
          property :author,  String, :nullable => false

          belongs_to :original, self, :nullable => true
          has n, :revisions, self, :child_key => [ :original_id ]
          has 1, :previous,  self, :child_key => [ :original_id ], :order => [ :id.desc ]
        end
      end

      @article_model = Blog::Article
    end

    supported_by :all do
      before :all do
        @author = 'Dan Kubb'

        @original = @article_model.create(:title => 'Original Article',                                               :author => @author)
        @article  = @article_model.create(:title => 'Sample Article',   :content => 'Sample', :original => @original, :author => @author)
        @other    = @article_model.create(:title => 'Other Article',    :content => 'Other',                          :author => @author)

        # load the targets without references to a single source
        load_collection = lambda do |query|
          @article_model.all(query)
        end

        @articles       = load_collection.call(:title => 'Sample Article', :author => @author)
        @other_articles = load_collection.call(:title => 'Other Article',  :author => @author)

        @articles.entries if loaded
      end

      it_should_behave_like 'A public Collection'
      it_should_behave_like 'A Collection supporting Strategic Eager Loading'
    end
  end
end
