require 'spec_helper'

# run the specs once with a loaded collection and once not
[ false, true ].each do |loaded|
  describe DataMapper::Collection do
    extend DataMapper::Spec::CollectionHelpers::GroupMethods

    self.loaded = loaded

    before :all do
      module ::Blog
        class Article
          include DataMapper::Resource

          property :id,         Serial
          property :title,      String, :required => true
          property :content,    Text
          property :subtitle,   String
          property :author,     String, :required => true
          property :attachment, Object

          belongs_to :original, self, :required => false
          has n, :revisions, self, :child_key => [ :original_id ]
          has 1, :previous,  self, :child_key => [ :original_id ], :order => [ :id.desc ]
          has n, :publications, :through => Resource

          def self.about_bobcats
            all(:content.like => '%bobcat%')
          end
        end

        class Publication
          include DataMapper::Resource

          property :id,   Serial
          property :name, String

          has n, :articles, :through => Resource
        end
      end

      DataMapper.finalize

      @article_model     = Blog::Article
      @publication_model = Blog::Publication
    end

    supported_by :all do
      before :all do
        @author       = 'Dan Kubb'
        @other_author = 'Chris Corbyn'

        # load the targets without references to a single source
        load_collection = lambda do |query|
          @article_model.all(query)
        end

        @original  = @article_model.create(:title => 'Original Article',                                               :author => @author)
        @article   = @article_model.create(:title => 'Sample Article',   :content => 'Sample', :original => @original, :author => @author)
        @other     = @article_model.create(:title => 'Other Article',    :content => 'Other',                          :author => @author)

        @articles          = load_collection.call(:title => 'Sample Article', :author => @author)
        @other_articles    = load_collection.call(:title => 'Other Article',  :author => @author)

        @articles.entries if loaded
      end

      it_should_behave_like 'A public Collection'
      it_should_behave_like 'A Collection supporting Strategic Eager Loading'
      it_should_behave_like 'Finder Interface'
      it_should_behave_like 'Collection Finder Interface'

      describe '#method_missing' do
        before :each do
          @author = 'Chris Corbyn'

          @no_bobcat    = @article_model.create(:title => 'About anything',   :content => 'Anything',              :author => @author)
          @wrong_bobcat = @article_model.create(:title => 'About a bobcat',   :content => 'A wrong bobcat he was', :author => 'Dan Kubb')
          @bobcat       = @article_model.create(:title => 'About a bobcat',   :content => 'A bobcat named Bob',    :author => @author)

          @all_articles      = @article_model.all
          @authored_articles = @article_model.all(:author => @author)
        end

        describe 'with a public model method for a scoped query' do
          before :each do
            @return = @authored_articles.about_bobcats
          end

          it 'should return the matching resource' do
            @return.should include(@bobcat)
          end

          it 'should not return resources out of scope' do
            @return.should_not include(@no_bobcat)
            @return.should_not include(@wrong_bobcat)
          end
        end

        describe 'with a union delegating to a public model method' do
          before :each do
            @return = (@authored_articles | @all_articles).about_bobcats
          end

          it 'should return the matching resource' do
            @return.should include(@bobcat)
          end

          it 'should not return resources out of scope' do
            @return.should_not include(@not_bobcat)
            @return.should_not include(@wrong_bobcat)
          end
        end
      end
    end
  end
end
