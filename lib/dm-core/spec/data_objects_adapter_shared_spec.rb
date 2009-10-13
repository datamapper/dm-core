share_examples_for 'A DataObjects Adapter' do
  before :all do
    raise '+@adapter+ should be defined in before block' unless instance_variable_get('@adapter')

    @log = StringIO.new

    @original_logger = DataMapper.logger
    DataMapper.logger = DataMapper::Logger.new(@log, :debug)

    # set up the adapter after switching the logger so queries can be captured
    @adapter = DataMapper.setup(@adapter.name, @adapter.options)
  end

  after :all do
    DataMapper.logger = @original_logger
  end

  def reset_log
    @log.truncate(0)
    @log.rewind
  end

  def log_output
    @log.rewind
    @log.read.chomp.gsub(/^\s+~ \(\d+\.?\d*\)\s+/, '')
  end

  def supports_default_values?
    @adapter.send(:supports_default_values?)
  end

  def supports_returning?
    @adapter.send(:supports_returning?)
  end

  describe '#create' do
    describe 'serial properties' do
      before :all do
        class ::Article
          include DataMapper::Resource

          property :id, Serial

          auto_migrate!
        end

        reset_log

        Article.create
      end

      it 'should not send NULL values' do
        statement = if defined?(DataMapper::Adapters::MysqlAdapter) && @adapter.kind_of?(DataMapper::Adapters::MysqlAdapter)
          /\AINSERT INTO `articles` \(\) VALUES \(\)\z/
        elsif supports_default_values? && supports_returning?
          /\AINSERT INTO "articles" DEFAULT VALUES RETURNING \"id\"\z/
        elsif supports_default_values?
          /\AINSERT INTO "articles" DEFAULT VALUES\z/
        else
          /\AINSERT INTO "articles" \(\) VALUES \(\)\z/
        end

        log_output.should =~ statement
      end
    end

    describe 'properties without a default' do
      before :all do
        class ::Article
          include DataMapper::Resource

          property :id,    Serial
          property :title, String

          auto_migrate!
        end

        reset_log

        Article.create(:id => 1)
      end

      it 'should not send NULL values' do
        if defined?(DataMapper::Adapters::MysqlAdapter) && @adapter.kind_of?(DataMapper::Adapters::MysqlAdapter)
          log_output.should =~ /^INSERT INTO `articles` \(`id`\) VALUES \(.{1,2}\)$/i
        elsif defined?(DataMapper::Adapters::SqlserverAdapter) && @adapter.kind_of?(DataMapper::Adapters::SqlserverAdapter)
          log_output.should =~ /^SET IDENTITY_INSERT \"articles\" ON INSERT INTO "articles" \("id"\) VALUES \(.{1,2}\) SET IDENTITY_INSERT \"articles\" OFF $/i
        else
          log_output.should =~ /^INSERT INTO "articles" \("id"\) VALUES \(.{1,2}\)$/i
        end
      end
    end
  end

  describe '#select' do
    before :all do
      class ::Article
        include DataMapper::Resource

        property :name,   String, :key => true
        property :author, String, :nullable => false

        auto_migrate!
      end

      @article_model = Article

      @article_model.create(:name => 'Learning DataMapper', :author => 'Dan Kubb')
    end

    describe 'when one field specified in SELECT statement' do
      before :all do
        @return = @adapter.select('SELECT name FROM articles')
      end

      it 'should return an Array' do
        @return.should be_kind_of(Array)
      end

      it 'should have a single result' do
        @return.size.should == 1
      end

      it 'should return an Array of values' do
        @return.should == [ 'Learning DataMapper' ]
      end
    end

    describe 'when more than one field specified in SELECT statement' do
      before :all do
        @return = @adapter.select('SELECT name, author FROM articles')
      end

      it 'should return an Array' do
        @return.should be_kind_of(Array)
      end

      it 'should have a single result' do
        @return.size.should == 1
      end

      it 'should return an Array of Struct objects' do
        @return.first.should be_kind_of(Struct)
      end

      it 'should return expected values' do
        @return.first.values.should == [ 'Learning DataMapper', 'Dan Kubb' ]
      end
    end
  end

  describe '#execute' do
    before :all do
      class ::Article
        include DataMapper::Resource

        property :name,   String, :key => true
        property :author, String, :nullable => false

        auto_migrate!
      end

      @article_model = Article
    end

    before :all do
      @result = @adapter.execute('INSERT INTO articles (name, author) VALUES(?, ?)', 'Learning DataMapper', 'Dan Kubb')
    end

    it 'should return a DataObjects::Result' do
      @result.should be_kind_of(DataObjects::Result)
    end

    it 'should affect 1 row' do
      @result.affected_rows.should == 1
    end

    it 'should not have an insert_id' do
      pending_if 'Inconsistent insert_id results', !(defined?(DataMapper::Adapters::PostgresAdapter) && @adapter.kind_of?(DataMapper::Adapters::PostgresAdapter)) do
        @result.insert_id.should be_nil
      end
    end
  end

  describe '#read' do
    before :all do
      class ::Article
        include DataMapper::Resource

        property :name, String, :key => true

        auto_migrate!
      end

      @article_model = Article
    end

    describe 'with a raw query' do
      before :all do
        @article_model.create(:name => 'Test').should be_saved

        @query = DataMapper::Query.new(@repository, @article_model, :conditions => [ 'name IS NOT NULL' ])

        @return = @adapter.read(@query)
      end

      it 'should return an Array of Hashes' do
        @return.should be_kind_of(Array)
        @return.all? { |entry| entry.should be_kind_of(Hash) }
      end

      it 'should return expected values' do
        @return.should == [ { @article_model.properties[:name] => 'Test' } ]
      end
    end

    describe 'with a raw query with a bind value mismatch' do
      before :all do
        @article_model.create(:name => 'Test').should be_saved

        @query = DataMapper::Query.new(@repository, @article_model, :conditions => [ 'name IS NOT NULL', nil ])
      end

      it 'should raise an error' do
        lambda {
          @adapter.read(@query)
        }.should raise_error(ArgumentError, 'Binding mismatch: 1 for 0')
      end
    end
  end
end
