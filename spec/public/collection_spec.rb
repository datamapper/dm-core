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

        belongs_to :original, :model => self
        has n, :revisions, :model => self, :child_key => [ :original_id ]
      end

      @model = Article
    end

    supported_by :all do
      before :all do
        @original = @model.create(:title => 'Original Article')
        @article  = @model.create(:title => 'Sample Article', :content => 'Sample', :original => @original)
        @other    = @model.create(:title => 'Other Article',  :content => 'Other')

        @articles       = @model.all(:title => 'Sample Article')
        @other_articles = @model.all(:title => 'Other Article')

        @articles.entries if loaded
      end

      it_should_behave_like 'A public Collection'
      it_should_behave_like 'A Collection supporting Strategic Eager Loading'
    end
  end
end
