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
        statement = if supports_default_values? && supports_returning?
          /^INSERT INTO "articles" .*DEFAULT.* RETURNING.*$/i
        elsif supports_default_values?
          /^INSERT INTO "articles" DEFAULT VALUES$/
        else
          /^INSERT INTO "articles" \(\) VALUES \(\)$/
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
        log_output.should =~ /^INSERT INTO "articles" \("id"\) VALUES \(.\)$/i
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
