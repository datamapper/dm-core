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
        end

        # create all tables and constraints before each spec
        if @repository.respond_to?(:auto_migrate!)
          Article.auto_migrate!
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
        end

        # create all tables and constraints before each spec
        if @repository.respond_to?(:auto_migrate!)
          Article.auto_migrate!
        end

        reset_log

        Article.create(:id => 1)
      end

      it 'should not send NULL values' do
        if defined?(DataMapper::Adapters::MysqlAdapter) && @adapter.kind_of?(DataMapper::Adapters::MysqlAdapter)
          log_output.should =~ /^INSERT INTO `articles` \(`id`\) VALUES \(.{1,2}\)$/i
        else
          log_output.should =~ /^INSERT INTO "articles" \("id"\) VALUES \(.{1,2}\)$/i
        end
      end
    end
  end

  describe '#execute' do
    it 'should allow queries without return results'
  end

  describe '#query' do
    it 'should allow queries with return results'
  end
end
