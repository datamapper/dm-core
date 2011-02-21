require 'spec_helper'

# TODO: move these specs into shared specs for #copy
describe DataMapper::Model do
  before :all do
    module ::Blog
      class Article
        include DataMapper::Resource

        property :id,       Serial
        property :title,    String, :required => true
        property :content,  Text,                       :writer => :private, :default => lambda { |resource, property| resource.title }
        property :subtitle, String
        property :author,   String, :required => true

        belongs_to :original, self, :required => false
        has n, :revisions, self, :child_key => [ :original_id ]
        has 1, :previous,  self, :child_key => [ :original_id ], :order => [ :id.desc ]
      end
    end
    DataMapper.finalize

    @article_model = Blog::Article
  end

  supported_by :all do
    before :all do
      @author = 'Dan Kubb'

      @original = @article_model.create(:title => 'Original Article',                         :author => @author)
      @article  = @article_model.create(:title => 'Sample Article',   :original => @original, :author => @author)
      @other    = @article_model.create(:title => 'Other Article',                            :author => @author)
    end

    it { @article_model.should respond_to(:copy) }

    describe '#copy' do
      with_alternate_adapter do
        describe 'between identical models' do
          before :all do
            @return = @resources = @article_model.copy(@repository.name, @adapter.name)
          end

          it 'should return a Collection' do
            @return.should be_a_kind_of(DataMapper::Collection)
          end

          it 'should return Resources' do
            @return.each { |resource| resource.should be_a_kind_of(DataMapper::Resource) }
          end

          it 'should have each Resource set to the expected Repository' do
            @resources.each { |resource| resource.repository.name.should == @adapter.name }
          end

          it 'should create the Resources in the expected Repository' do
            @article_model.all(:repository => DataMapper.repository(@adapter.name)).should == @resources
          end
        end

        describe 'between different models' do
          before :all do
            @other.destroy
            @article.destroy
            @original.destroy

            # make sure the default repository is empty
            @article_model.all(:repository => @repository).should be_empty

            # add an extra property to the alternate model
            DataMapper.repository(@adapter.name) do
              @article_model.property :status, String, :default => 'new'
            end

            if @article_model.respond_to?(:auto_migrate!)
              @article_model.auto_migrate!(@adapter.name)
            end

            # add new resources to the alternate repository
            DataMapper.repository(@adapter.name) do
              # use an id value that is unique
              @heff1 = @article_model.create(:id => 99, :title => 'Alternate Repository', :author => @author)
            end

            # copy from the alternate to the default repository
            @return = @resources = @article_model.copy(@adapter.name, :default)
          end

          it 'should return a Collection' do
            @return.should be_a_kind_of(DataMapper::Collection)
          end

          it 'should return Resources' do
            @return.each { |resource| resource.should be_a_kind_of(DataMapper::Resource) }
          end

          it 'should have each Resource set to the expected Repository' do
            @resources.each { |resource| resource.repository.name.should == :default }
          end

          it 'should return the expected resources' do
            # match on id because resources from different repositories are different
            @resources.map { |resource| resource.id }.should == [ @heff1.id ]
          end

          it 'should add the resources to the alternate repository' do
            @article.model.get(*@heff1.key).should_not be_nil
          end
        end
      end
    end
  end
end

describe DataMapper::Model do
  extend DataMapper::Spec::CollectionHelpers::GroupMethods

  self.loaded = false

  before :all do
    module ::Blog
      class Article
        include DataMapper::Resource

        property :id,       Serial
        property :title,    String, :required => true, :default => 'Default Title'
        property :content,  Text
        property :subtitle, String

        belongs_to :original, self, :required => false
        has n, :revisions, self, :child_key => [ :original_id ]
        has 1, :previous,  self, :child_key => [ :original_id ], :order => [ :id.desc ]
        has n, :publications, :through => Resource
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
    # model cannot be a kicker
    def should_not_be_a_kicker; end

    def model?; true end

    before :all do
      @articles = @article_model

      @original = @articles.create(:title => 'Original Article')
      @article  = @articles.create(:title => 'Sample Article', :content => 'Sample', :original => @original)
      @other    = @articles.create(:title => 'Other Article',  :content => 'Other')
    end

    describe '#new' do
      subject { model.new(*args) }

      let(:model) { @article_model }

      context 'with no arguments' do
        let(:args) { [] }

        it { should be_instance_of(model) }

        its(:attributes) { should == { :title => 'Default Title' } }
      end

      context 'with an empty Hash' do
        let(:args) { [ {} ] }

        it { should be_instance_of(model) }

        its(:attributes) { should == { :title => 'Default Title' } }
      end

      context 'with a non-empty Hash' do
        let(:attributes) { { :title => 'A Title' } }
        let(:args)       { [ attributes ]          }

        it { should be_instance_of(model) }

        its(:attributes) { should == attributes }
      end

      context 'with nil' do
        let(:args) { [ nil ] }

        it { should be_instance_of(model) }

        its(:attributes) { should == { :title => 'Default Title' } }
      end
    end

    [ :create, :create! ].each do |method|
      describe "##{method}" do
        subject { model.send(method, *args) }

        let(:model) { @article_model }

        context 'with no arguments' do
          let(:args) { [] }

          it { should be_instance_of(model) }

          it { should be_saved }
        end

        context 'with an empty Hash' do
          let(:args) { [ {} ] }

          it { should be_instance_of(model) }

          it { should be_saved }
        end

        context 'with a non-empty Hash' do
          let(:attributes) { { :title => 'A Title' } }
          let(:args)       { [ attributes ]          }

          it { should be_instance_of(model) }

          it { should be_saved }

          its(:title) { should == attributes[:title] }
        end

        context 'with nil' do
          let(:args) { [ nil ] }

          it { should be_instance_of(model) }

          it { should be_saved }
        end
      end
    end

    [ :destroy, :destroy! ].each do |method|
      describe "##{method}" do
        subject { model.send(method) }

        let(:model) { @article_model }

        it 'should remove all resources' do
          method(:subject).should change { model.any? }.from(true).to(false)
        end
      end
    end

    [ :update, :update! ].each do |method|
      describe "##{method}" do
        subject { model.send(method, *args) }

        let(:model) { @article_model }

        context 'with attributes' do
          let(:attributes) { { :title => 'Updated Title' } }
          let(:args)       { [ attributes ]                }

          it { should be(true) }

          it 'should persist the changes' do
            subject
            model.all(:fields => [ :title ]).map { |resource| resource.title }.uniq.should == [ attributes[:title] ]
          end
        end

        context 'with attributes where one is a parent association' do
          let(:attributes) { { :original => @other } }
          let(:args)       { [ attributes ]          }

          it { should be(true) }

          it 'should persist the changes' do
            subject
            model.all(:fields => [ :original_id ]).map { |resource| resource.original }.uniq.should == [ attributes[:original] ]
          end
        end

        context 'with attributes where a required property is nil' do
          let(:attributes) { { :title => nil } }
          let(:args)       { [ attributes ]    }

          it { should be(false) }
        end
      end
    end

    it_should_behave_like 'Finder Interface'

    it 'DataMapper::Model should respond to raise_on_save_failure' do
      DataMapper::Model.should respond_to(:raise_on_save_failure)
    end

    describe '.raise_on_save_failure' do
      subject { DataMapper::Model.raise_on_save_failure }

      it { should be(false) }
    end

    it 'DataMapper::Model should respond to raise_on_save_failure=' do
      DataMapper::Model.should respond_to(:raise_on_save_failure=)
    end

    describe '.raise_on_save_failure=' do
      after do
        # reset to the default value
        reset_raise_on_save_failure(DataMapper::Model)
      end

      subject { DataMapper::Model.raise_on_save_failure = @value }

      describe 'with a true value' do
        before do
          @value = true
        end

        it { should be(true) }

        it 'should set raise_on_save_failure' do
          method(:subject).should change {
            DataMapper::Model.raise_on_save_failure
          }.from(false).to(true)
        end
      end

      describe 'with a false value' do
        before do
          @value = false
        end

        it { should be(false) }

        it 'should set raise_on_save_failure' do
          method(:subject).should_not change {
            DataMapper::Model.raise_on_save_failure
          }
        end
      end
    end

    it 'A model should respond to raise_on_save_failure' do
      @article_model.should respond_to(:raise_on_save_failure)
    end

    describe '#raise_on_save_failure' do
      after do
        # reset to the default value
        reset_raise_on_save_failure(DataMapper::Model)
        reset_raise_on_save_failure(@article_model)
      end

      subject { @article_model.raise_on_save_failure }

      describe 'when DataMapper::Model.raise_on_save_failure has not been set' do
        it { should be(false) }
      end

      describe 'when DataMapper::Model.raise_on_save_failure has been set to true' do
        before do
          DataMapper::Model.raise_on_save_failure = true
        end

        it { should be(true) }
      end

      describe 'when model.raise_on_save_failure has been set to true' do
        before do
          @article_model.raise_on_save_failure = true
        end

        it { should be(true) }
      end
    end

    it 'A model should respond to raise_on_save_failure=' do
      @article_model.should respond_to(:raise_on_save_failure=)
    end

    describe '#raise_on_save_failure=' do
      after do
        # reset to the default value
        reset_raise_on_save_failure(@article_model)
      end

      subject { @article_model.raise_on_save_failure = @value }

      describe 'with a true value' do
        before do
          @value = true
        end

        it { should be(true) }

        it 'should set raise_on_save_failure' do
          method(:subject).should change {
            @article_model.raise_on_save_failure
          }.from(false).to(true)
        end
      end

      describe 'with a false value' do
        before do
          @value = false
        end

        it { should be(false) }

        it 'should set raise_on_save_failure' do
          method(:subject).should_not change {
            @article_model.raise_on_save_failure
          }
        end
      end
    end
  end
end
