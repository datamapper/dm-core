require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

describe DataMapper::Migrations do
  def capture_log(mod)
    original, mod.logger = mod.logger, DataObjects::Logger.new(@log = StringIO.new, :debug)
    yield
  ensure
    @log.rewind
    @output = @log.readlines.map do |line|
      line.chomp.gsub(/\A.+?~ \(\d+\.?\d*\)\s+/, '')
    end

    mod.logger = original
  end

  supported_by :mysql do
    before :all do
      module ::Blog
        class Article
          include DataMapper::Resource
        end
      end

      @model = ::Blog::Article
    end

    describe '#auto_migrate' do
      describe 'Integer property' do
        [
          [                    0,                    1, 'TINYINT(1) UNSIGNED'   ],
          [                    0,                    9, 'TINYINT(1) UNSIGNED'   ],
          [                    0,                   10, 'TINYINT(2) UNSIGNED'   ],
          [                    0,                   99, 'TINYINT(2) UNSIGNED'   ],
          [                    0,                  100, 'TINYINT(3) UNSIGNED'   ],
          [                    0,                  255, 'TINYINT(3) UNSIGNED'   ],
          [                    0,                  256, 'SMALLINT(3) UNSIGNED'  ],
          [                    0,                  999, 'SMALLINT(3) UNSIGNED'  ],
          [                    0,                 1000, 'SMALLINT(4) UNSIGNED'  ],
          [                    0,                 9999, 'SMALLINT(4) UNSIGNED'  ],
          [                    0,                10000, 'SMALLINT(5) UNSIGNED'  ],
          [                    0,                65535, 'SMALLINT(5) UNSIGNED'  ],
          [                    0,                65536, 'MEDIUMINT(5) UNSIGNED' ],
          [                    0,                99999, 'MEDIUMINT(5) UNSIGNED' ],
          [                    0,               100000, 'MEDIUMINT(6) UNSIGNED' ],
          [                    0,               999999, 'MEDIUMINT(6) UNSIGNED' ],
          [                    0,              1000000, 'MEDIUMINT(7) UNSIGNED' ],
          [                    0,              9999999, 'MEDIUMINT(7) UNSIGNED' ],
          [                    0,             10000000, 'MEDIUMINT(8) UNSIGNED' ],
          [                    0,             16777215, 'MEDIUMINT(8) UNSIGNED' ],
          [                    0,             16777216, 'INT(8) UNSIGNED'       ],
          [                    0,             99999999, 'INT(8) UNSIGNED'       ],
          [                    0,            100000000, 'INT(9) UNSIGNED'       ],
          [                    0,            999999999, 'INT(9) UNSIGNED'       ],
          [                    0,           1000000000, 'INT(10) UNSIGNED'      ],
          [                    0,           4294967295, 'INT(10) UNSIGNED'      ],
          [                    0,           4294967296, 'BIGINT(10) UNSIGNED'   ],
          [                    0,           9999999999, 'BIGINT(10) UNSIGNED'   ],
          [                    0,          10000000000, 'BIGINT(11) UNSIGNED'   ],
          [                    0,          99999999999, 'BIGINT(11) UNSIGNED'   ],
          [                    0,         100000000000, 'BIGINT(12) UNSIGNED'   ],
          [                    0,         999999999999, 'BIGINT(12) UNSIGNED'   ],
          [                    0,        1000000000000, 'BIGINT(13) UNSIGNED'   ],
          [                    0,        9999999999999, 'BIGINT(13) UNSIGNED'   ],
          [                    0,       10000000000000, 'BIGINT(14) UNSIGNED'   ],
          [                    0,       99999999999999, 'BIGINT(14) UNSIGNED'   ],
          [                    0,      100000000000000, 'BIGINT(15) UNSIGNED'   ],
          [                    0,      999999999999999, 'BIGINT(15) UNSIGNED'   ],
          [                    0,     1000000000000000, 'BIGINT(16) UNSIGNED'   ],
          [                    0,     9999999999999999, 'BIGINT(16) UNSIGNED'   ],
          [                    0,    10000000000000000, 'BIGINT(17) UNSIGNED'   ],
          [                    0,    99999999999999999, 'BIGINT(17) UNSIGNED'   ],
          [                    0,   100000000000000000, 'BIGINT(18) UNSIGNED'   ],
          [                    0,   999999999999999999, 'BIGINT(18) UNSIGNED'   ],
          [                    0,  1000000000000000000, 'BIGINT(19) UNSIGNED'   ],
          [                    0,  9999999999999999999, 'BIGINT(19) UNSIGNED'   ],
          [                    0, 10000000000000000000, 'BIGINT(20) UNSIGNED'   ],
          [                    0, 18446744073709551615, 'BIGINT(20) UNSIGNED'   ],

          [                   -1,                    0, 'TINYINT(2)'            ],
          [                   -1,                    9, 'TINYINT(2)'            ],
          [                   -1,                   10, 'TINYINT(2)'            ],
          [                   -1,                   99, 'TINYINT(2)'            ],
          [                   -1,                  100, 'TINYINT(3)'            ],
          [                   -1,                  127, 'TINYINT(3)'            ],
          [                   -1,                  128, 'SMALLINT(3)'           ],
          [                   -1,                  999, 'SMALLINT(3)'           ],
          [                   -1,                 1000, 'SMALLINT(4)'           ],
          [                   -1,                 9999, 'SMALLINT(4)'           ],
          [                   -1,                10000, 'SMALLINT(5)'           ],
          [                   -1,                32767, 'SMALLINT(5)'           ],
          [                   -1,                32768, 'MEDIUMINT(5)'          ],
          [                   -1,                99999, 'MEDIUMINT(5)'          ],
          [                   -1,               100000, 'MEDIUMINT(6)'          ],
          [                   -1,               999999, 'MEDIUMINT(6)'          ],
          [                   -1,              1000000, 'MEDIUMINT(7)'          ],
          [                   -1,              8388607, 'MEDIUMINT(7)'          ],
          [                   -1,              8388608, 'INT(7)'                ],
          [                   -1,              9999999, 'INT(7)'                ],
          [                   -1,             10000000, 'INT(8)'                ],
          [                   -1,             99999999, 'INT(8)'                ],
          [                   -1,            100000000, 'INT(9)'                ],
          [                   -1,            999999999, 'INT(9)'                ],
          [                   -1,           1000000000, 'INT(10)'               ],
          [                   -1,           2147483647, 'INT(10)'               ],
          [                   -1,           2147483648, 'BIGINT(10)'            ],
          [                   -1,           9999999999, 'BIGINT(10)'            ],
          [                   -1,          10000000000, 'BIGINT(11)'            ],
          [                   -1,          99999999999, 'BIGINT(11)'            ],
          [                   -1,         100000000000, 'BIGINT(12)'            ],
          [                   -1,         999999999999, 'BIGINT(12)'            ],
          [                   -1,        1000000000000, 'BIGINT(13)'            ],
          [                   -1,        9999999999999, 'BIGINT(13)'            ],
          [                   -1,       10000000000000, 'BIGINT(14)'            ],
          [                   -1,       99999999999999, 'BIGINT(14)'            ],
          [                   -1,      100000000000000, 'BIGINT(15)'            ],
          [                   -1,      999999999999999, 'BIGINT(15)'            ],
          [                   -1,     1000000000000000, 'BIGINT(16)'            ],
          [                   -1,     9999999999999999, 'BIGINT(16)'            ],
          [                   -1,    10000000000000000, 'BIGINT(17)'            ],
          [                   -1,    99999999999999999, 'BIGINT(17)'            ],
          [                   -1,   100000000000000000, 'BIGINT(18)'            ],
          [                   -1,   999999999999999999, 'BIGINT(18)'            ],
          [                   -1,  1000000000000000000, 'BIGINT(19)'            ],
          [                   -1,  9223372036854775807, 'BIGINT(19)'            ],

          [                   -1,                    0, 'TINYINT(2)'            ],
          [                   -9,                    0, 'TINYINT(2)'            ],
          [                  -10,                    0, 'TINYINT(3)'            ],
          [                  -99,                    0, 'TINYINT(3)'            ],
          [                 -100,                    0, 'TINYINT(4)'            ],
          [                 -128,                    0, 'TINYINT(4)'            ],
          [                 -129,                    0, 'SMALLINT(4)'           ],
          [                 -999,                    0, 'SMALLINT(4)'           ],
          [                -1000,                    0, 'SMALLINT(5)'           ],
          [                -9999,                    0, 'SMALLINT(5)'           ],
          [               -10000,                    0, 'SMALLINT(6)'           ],
          [               -32768,                    0, 'SMALLINT(6)'           ],
          [               -32769,                    0, 'MEDIUMINT(6)'          ],
          [               -99999,                    0, 'MEDIUMINT(6)'          ],
          [              -100000,                    0, 'MEDIUMINT(7)'          ],
          [              -999999,                    0, 'MEDIUMINT(7)'          ],
          [             -1000000,                    0, 'MEDIUMINT(8)'          ],
          [             -8388608,                    0, 'MEDIUMINT(8)'          ],
          [             -8388609,                    0, 'INT(8)'                ],
          [             -9999999,                    0, 'INT(8)'                ],
          [            -10000000,                    0, 'INT(9)'                ],
          [            -99999999,                    0, 'INT(9)'                ],
          [           -100000000,                    0, 'INT(10)'               ],
          [           -999999999,                    0, 'INT(10)'               ],
          [          -1000000000,                    0, 'INT(11)'               ],
          [          -2147483648,                    0, 'INT(11)'               ],
          [          -2147483649,                    0, 'BIGINT(11)'            ],
          [          -9999999999,                    0, 'BIGINT(11)'            ],
          [         -10000000000,                    0, 'BIGINT(12)'            ],
          [         -99999999999,                    0, 'BIGINT(12)'            ],
          [        -100000000000,                    0, 'BIGINT(13)'            ],
          [        -999999999999,                    0, 'BIGINT(13)'            ],
          [       -1000000000000,                    0, 'BIGINT(14)'            ],
          [       -9999999999999,                    0, 'BIGINT(14)'            ],
          [      -10000000000000,                    0, 'BIGINT(15)'            ],
          [      -99999999999999,                    0, 'BIGINT(15)'            ],
          [     -100000000000000,                    0, 'BIGINT(16)'            ],
          [     -999999999999999,                    0, 'BIGINT(16)'            ],
          [    -1000000000000000,                    0, 'BIGINT(17)'            ],
          [    -9999999999999999,                    0, 'BIGINT(17)'            ],
          [   -10000000000000000,                    0, 'BIGINT(18)'            ],
          [   -99999999999999999,                    0, 'BIGINT(18)'            ],
          [  -100000000000000000,                    0, 'BIGINT(19)'            ],
          [  -999999999999999999,                    0, 'BIGINT(19)'            ],
          [ -1000000000000000000,                    0, 'BIGINT(20)'            ],
          [ -9223372036854775808,                    0, 'BIGINT(20)'            ],

          [                  nil,           2147483647, 'INT(10) UNSIGNED'      ],
          [                    0,                  nil, 'INT(10) UNSIGNED'      ],
          [                  nil,                  nil, 'INTEGER'               ],
        ].each do |min, max, statement|
          options = { :key => true }
          options[:min] = min if min
          options[:max] = max if max

          describe "with a min of #{min} and a max of #{max}" do
            before :all do
              @property = @model.property(:id, Integer, options)

              @response = capture_log(DataObjects::Mysql) { @model.auto_migrate! }
            end

            it 'should return true' do
              @response.should be_true
            end

            it "should create a #{statement} column" do
              @output.last.should =~ %r{\ACREATE TABLE `blog_articles` \(`id` #{Regexp.escape(statement)} NOT NULL, PRIMARY KEY\(`id`\)\) ENGINE = InnoDB CHARACTER SET [a-z\d]+ COLLATE (?:[a-z\d](?:_?[a-z\d]+)*)\z}
            end

            options.only(:min, :max).each do |key, value|
              it "should allow the #{key} value #{value} to be stored" do
                lambda {
                  resource = @model.create(@property => value)
                  @model.first(@property => value).should eql(resource)
                }.should_not raise_error
              end
            end
          end
        end
      end

      describe 'Text property' do
        before :all do
          @model.property(:id, DataMapper::Types::Serial)
        end

        [
          [ 0,          'TINYTEXT'   ],
          [ 1,          'TINYTEXT'   ],
          [ 255,        'TINYTEXT'   ],
          [ 256,        'TEXT'       ],
          [ 65535,      'TEXT'       ],
          [ 65536,      'MEDIUMTEXT' ],
          [ 16777215,   'MEDIUMTEXT' ],
          [ 16777216,   'LONGTEXT'   ],
          [ 4294967295, 'LONGTEXT'   ],

          [ nil,        'TEXT'       ],
        ].each do |length, statement|
          options = {}
          options[:length] = length if length

          describe "with a length of #{length}" do
            before :all do
              @property = @model.property(:body, DataMapper::Types::Text, options)

              @response = capture_log(DataObjects::Mysql) { @model.auto_migrate! }
            end

            it 'should return true' do
              @response.should be_true
            end

            it "should create a #{statement} column" do
              @output.last.should =~ %r{\ACREATE TABLE `blog_articles` \(`id` INT\(10\) UNSIGNED NOT NULL AUTO_INCREMENT, `body` #{Regexp.escape(statement)}, PRIMARY KEY\(`id`\)\) ENGINE = InnoDB CHARACTER SET [a-z\d]+ COLLATE (?:[a-z\d](?:_?[a-z\d]+)*)\z}
            end
          end
        end
      end

      describe 'String property' do
        before :all do
          @model.property(:id, DataMapper::Types::Serial)
        end

        [
          [ 1,          'VARCHAR(1)'   ],
          [ 50,         'VARCHAR(50)'  ],
          [ 255,        'VARCHAR(255)' ],
          [ nil,        'VARCHAR(50)'  ],
        ].each do |length, statement|
          options = {}
          options[:length] = length if length

          describe "with a length of #{length}" do
            before :all do
              @property = @model.property(:title, String, options)

              @response = capture_log(DataObjects::Mysql) { @model.auto_migrate! }
            end

            it 'should return true' do
              @response.should be_true
            end

            it "should create a #{statement} column" do
              @output.last.should =~ %r{\ACREATE TABLE `blog_articles` \(`id` INT\(10\) UNSIGNED NOT NULL AUTO_INCREMENT, `title` #{Regexp.escape(statement)}, PRIMARY KEY\(`id`\)\) ENGINE = InnoDB CHARACTER SET [a-z\d]+ COLLATE (?:[a-z\d](?:_?[a-z\d]+)*)\z}
            end
          end
        end
      end
    end
  end

  supported_by :postgres do
    before :all do
      module ::Blog
        class Article
          include DataMapper::Resource
        end
      end

      @model = ::Blog::Article
    end

    describe '#auto_migrate' do
      describe 'Integer property' do
        [
          [                    0,                   1, 'SMALLINT' ],
          [                    0,               32767, 'SMALLINT' ],
          [                    0,               32768, 'INTEGER'  ],
          [                    0,          2147483647, 'INTEGER'  ],
          [                    0,          2147483648, 'BIGINT'   ],
          [                    0, 9223372036854775807, 'BIGINT'   ],

          [                   -1,                   1, 'SMALLINT' ],
          [                   -1,               32767, 'SMALLINT' ],
          [                   -1,               32768, 'INTEGER'  ],
          [                   -1,          2147483647, 'INTEGER'  ],
          [                   -1,          2147483648, 'BIGINT'   ],
          [                   -1, 9223372036854775807, 'BIGINT'   ],

          [                   -1,                   0, 'SMALLINT' ],
          [               -32768,                   0, 'SMALLINT' ],
          [               -32769,                   0, 'INTEGER'  ],
          [          -2147483648,                   0, 'INTEGER'  ],
          [          -2147483649,                   0, 'BIGINT'   ],
          [ -9223372036854775808,                   0, 'BIGINT'   ],

          [                  nil,          2147483647, 'INTEGER'  ],
          [                    0,                 nil, 'INTEGER'  ],
          [                  nil,                 nil, 'INTEGER'  ],
        ].each do |min, max, statement|
          options = { :key => true }
          options[:min] = min if min
          options[:max] = max if max

          describe "with a min of #{min} and a max of #{max}" do
            before :all do
              @property = @model.property(:id, Integer, options)

              @response = capture_log(DataObjects::Postgres) { @model.auto_migrate! }
            end

            it 'should return true' do
              @response.should be_true
            end

            it "should create a #{statement} column" do
              @output[-2].should == "CREATE TABLE \"blog_articles\" (\"id\" #{statement} NOT NULL, PRIMARY KEY(\"id\"))"
            end

            options.only(:min, :max).each do |key, value|
              it "should allow the #{key} value #{value} to be stored" do
                lambda {
                  resource = @model.create(@property => value)
                  @model.first(@property => value).should eql(resource)
                }.should_not raise_error
              end
            end
          end
        end
      end

      describe 'Serial property' do
        [
          [                   1, 'SERIAL'    ],
          [          2147483647, 'SERIAL'    ],
          [          2147483648, 'BIGSERIAL' ],
          [ 9223372036854775807, 'BIGSERIAL' ],

          [                 nil, 'SERIAL'    ],
        ].each do |max, statement|
          options = {}
          options[:max] = max if max

          describe "with a max of #{max}" do
            before :all do
              @property = @model.property(:id, DataMapper::Types::Serial, options)

              @response = capture_log(DataObjects::Postgres) { @model.auto_migrate! }
            end

            it 'should return true' do
              @response.should be_true
            end

            it "should create a #{statement} column" do
              @output[-2].should == "CREATE TABLE \"blog_articles\" (\"id\" #{statement} NOT NULL, PRIMARY KEY(\"id\"))"
            end

            options.only(:min, :max).each do |key, value|
              it "should allow the #{key} value #{value} to be stored" do
                lambda {
                  resource = @model.create(@property => value)
                  @model.first(@property => value).should eql(resource)
                }.should_not raise_error
              end
            end
          end
        end
      end

      describe 'String property' do
        before :all do
          @model.property(:id, DataMapper::Types::Serial)
        end

        [
          [ 1,          'VARCHAR(1)'   ],
          [ 50,         'VARCHAR(50)'  ],
          [ 255,        'VARCHAR(255)' ],
          [ nil,        'VARCHAR(50)'  ],
        ].each do |length, statement|
          options = {}
          options[:length] = length if length

          describe "with a length of #{length}" do
            before :all do
              @property = @model.property(:title, String, options)

              @response = capture_log(DataObjects::Postgres) { @model.auto_migrate! }
            end

            it 'should return true' do
              @response.should be_true
            end

            it "should create a #{statement} column" do
              @output[-2].should == "CREATE TABLE \"blog_articles\" (\"id\" SERIAL NOT NULL, \"title\" #{statement}, PRIMARY KEY(\"id\"))"
            end
          end
        end
      end
    end
  end

  supported_by :sqlserver do
    before :all do
      module ::Blog
        class Article
          include DataMapper::Resource
        end
      end

      @model = ::Blog::Article
    end

    describe '#auto_migrate' do
      describe 'Integer property' do
        [
          [                    0,                   1, 'TINYINT'  ],
          [                    0,                 255, 'TINYINT'  ],
          [                    0,                 256, 'SMALLINT' ],
          [                    0,               32767, 'SMALLINT' ],
          [                    0,               32768, 'INT'      ],
          [                    0,          2147483647, 'INT'      ],
          [                    0,          2147483648, 'BIGINT'   ],
          [                    0, 9223372036854775807, 'BIGINT'   ],

          [                   -1,                   1, 'SMALLINT' ],
          [                   -1,                 255, 'SMALLINT' ],
          [                   -1,                 256, 'SMALLINT' ],
          [                   -1,               32767, 'SMALLINT' ],
          [                   -1,               32768, 'INT'      ],
          [                   -1,          2147483647, 'INT'      ],
          [                   -1,          2147483648, 'BIGINT'   ],
          [                   -1, 9223372036854775807, 'BIGINT'   ],

          [                   -1,                   0, 'SMALLINT' ],
          [               -32768,                   0, 'SMALLINT' ],
          [               -32769,                   0, 'INT'      ],
          [          -2147483648,                   0, 'INT'      ],
          [          -2147483649,                   0, 'BIGINT'   ],
          [ -9223372036854775808,                   0, 'BIGINT'   ],

          [                  nil,          2147483647, 'INT'      ],
          [                    0,                 nil, 'INT'      ],
          [                  nil,                 nil, 'INTEGER'  ],
        ].each do |min, max, statement|
          options = { :key => true }
          options[:min] = min if min
          options[:max] = max if max

          describe "with a min of #{min} and a max of #{max}" do
            before :all do
              @property = @model.property(:id, Integer, options)

              @response = capture_log(DataObjects::Sqlserver) { @model.auto_migrate! }
            end

            it 'should return true' do
              @response.should be_true
            end

            it "should create a #{statement} column" do
              @output.last.should == "CREATE TABLE \"blog_articles\" (\"id\" #{statement} NOT NULL, PRIMARY KEY(\"id\"))"
            end

            options.only(:min, :max).each do |key, value|
              it "should allow the #{key} value #{value} to be stored" do
                lambda {
                  resource = @model.create(@property => value)
                  @model.first(@property => value).should eql(resource)
                }.should_not raise_error
              end
            end
          end
        end
      end

      describe 'String property' do
        it 'needs specs'
      end
    end
  end
end
