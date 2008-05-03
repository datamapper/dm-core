require 'pathname'
require Pathname(__FILE__).dirname.expand_path.parent + 'spec_helper'
require 'ostruct'

TODAY = Date.today
NOW   = DateTime.now

class Book
  include DataMapper::Resource

  property :serial,      Fixnum,     :serial => true
  property :fixnum,      Fixnum,     :nullable => false, :default => 1
  property :string,      String,     :nullable => false, :default => 'default'
  property :date,        Date,       :nullable => false, :default => TODAY
  property :true_class,  TrueClass,  :nullable => false, :default => true
  property :false_class, TrueClass,  :nullable => false, :default => false
  property :text,        DM::Text,   :nullable => false, :default => 'text'
#  property :class,       Class,      :nullable => false, :default => Class  # FIXME: Class types cause infinite recursions in Resource
  property :big_decimal, BigDecimal, :nullable => false, :default => BigDecimal('1.1')
  property :float,       Float,      :nullable => false, :default => 1.1
  property :date_time,   DateTime,   :nullable => false, :default => NOW
  property :object,      Object,     :nullable => true                       # FIXME: cannot supply a default for Object
end

begin
  require 'do_sqlite3'

  DataMapper.setup(:sqlite3, "sqlite3://#{INTEGRATION_DB_PATH}")

  describe DataMapper::AutoMigrations, '.auto_migrate!' do
    before :all do
      @adapter = repository(:sqlite3).adapter

      DataMapper::AutoMigrator.models.clear

      @property_class = Struct.new(:name, :type, :nullable, :default, :serial)
    end

    after :all do
      DataMapper::AutoMigrator.models.clear
    end

    describe 'with sqlite3' do


      before :all do
        Book.auto_migrate!(:sqlite3)

        @table_set = @adapter.query('PRAGMA table_info("books")').inject({}) do |ts,column|
          default = if 'NULL' == column.dflt_value || column.dflt_value.nil?
            nil
          else
            /^(['"]?)(.*)\1$/.match(column.dflt_value)[2]
          end

          property = @property_class.new(
            column.name,
            column.type.upcase,
            column.notnull == 0,
            default,
            column.pk == 1  # in SQLite3 the serial key is also primary
          )

          ts.update(property.name => property)
        end

        repository(:sqlite3) do
          Book.create!
          @book = Book.first(:fields => [ :serial, :fixnum, :string, :date, :true_class, :false_class, :text, :big_decimal, :float, :date_time ])
        end
      end

      types = {
        :serial      => [ Fixnum,     'INTEGER',     false, nil,                               1,                 true  ],
        :fixnum      => [ Fixnum,     'INTEGER',     false, '1',                               1,                 false ],
        :string      => [ String,     'VARCHAR(50)', false, 'default',                         'default',         false ],
        :date        => [ Date,       'DATE',        false, TODAY.strftime('%Y-%m-%d'),        TODAY,             false ],
        :true_class  => [ TrueClass,  'BOOLEAN',     false, 't',                               true,              false ],
        :false_class => [ TrueClass,  'BOOLEAN',     false, 'f',                               false,             false ],
        :text        => [ DM::Text,   'TEXT',        false, 'text',                            'text',            false ],
#        :class       => [ Class,      'VARCHAR(50)', false, 'Class',                           'Class',           false ],
        :big_decimal => [ BigDecimal, 'DECIMAL',     false, BigDecimal('1.1').to_s('F'),       BigDecimal('1.1'), false ],
        :float       => [ Float,      'FLOAT',       false, '1.1',                             1.1,               false ],
        :date_time   => [ DateTime,   'DATETIME',    false, NOW.strftime('%Y-%m-%d %H:%M:%S'), NOW,               false ],
        :object      => [ Object,     'TEXT',        true,  nil,                               nil,                false ],
      }

      types.each do |name,(klass,type,nullable,default,key)|
        describe "a #{klass} property" do
          it "should be created as a #{type}" do
            @table_set[name.to_s].type.should == type
          end

          it "should #{!nullable && 'not'} be nullable".squeeze(' ') do
            @table_set[name.to_s].nullable.should == nullable
          end

          it "should have a default value #{default.inspect}" do
            @table_set[name.to_s].default.should == default
          end

          expected_value = types[name][4]
          it "should have an typecasted value #{expected_value.inspect}" do
            @book.send(name).should == expected_value
          end
        end
      end
    end
  end
rescue LoadError => e
  describe 'do_sqlite3' do
    it 'should be required' do
      fail "SQLite3 integration specs not run! Could not load do_sqlite3: #{e}"
    end
  end
end

begin
  require 'do_mysql'

  DataMapper.setup(:mysql, 'mysql://localhost/dm_integration_test')

  describe DataMapper::AutoMigrations, '.auto_migrate!' do
    before :all do
      @adapter = repository(:mysql).adapter

      DataMapper::AutoMigrator.models.clear

      @property_class = Struct.new(:name, :type, :nullable, :default, :serial)
    end

    after :all do
      DataMapper::AutoMigrator.models.clear
    end

    describe 'with mysql' do#
      before :all do
        Book.auto_migrate!(:mysql)

        @table_set = @adapter.query('DESCRIBE `books`').inject({}) do |ts,column|
          property = @property_class.new(
            column.field,
            column.type.upcase,
            column.null == 'YES',
            column.default,
            column.extra.split.include?('auto_increment')
          )

          ts.update(property.name => property)
        end

        repository(:mysql) do
          Book.create!
          @book = Book.first
        end
      end

      types = {
        :serial      => [ Fixnum,     'INT(11)',       false, nil,                               1,                 true  ],
        :fixnum      => [ Fixnum,     'INT(11)',       false, '1',                               1,                 false ],
        :string      => [ String,     'VARCHAR(50)',   false, 'default',                         'default',         false ],
        :date        => [ Date,       'DATE',          false, TODAY.strftime('%Y-%m-%d'),        TODAY,             false ],
        :true_class  => [ TrueClass,  'TINYINT(1)',    false, '1',                               true,              false ],
        :false_class => [ TrueClass,  'TINYINT(1)',    false, '0',                               false,             false ],
        :text        => [ DM::Text,   'TEXT',          false, nil,                               'text',            false ],
#        :class       => [ Class,      'VARCHAR(50)',   false, 'Class',                           'Class',           false ],
        :big_decimal => [ BigDecimal, 'DECIMAL(10,0)', false, '1',                               BigDecimal('1.1'), false ],
        :float       => [ Float,      'FLOAT',         false, '1.1',                             1.1,               false ],
        :date_time   => [ DateTime,   'DATETIME',      false, NOW.strftime('%Y-%m-%d %H:%M:%S'), NOW,               false ],
        :object      => [ Object,     'TEXT',          true,  nil,                               nil,               false ],
      }

      types.each do |name,(klass,type,nullable,default,key)|
        describe "a #{klass} property" do
          it "should be created as a #{type}" do
            @table_set[name.to_s].type.should == type
          end

          it "should #{!nullable && 'not'} be nullable".squeeze(' ') do
            @table_set[name.to_s].nullable.should == nullable
          end

          it "should have a default value #{default.inspect}" do
            @table_set[name.to_s].default.should == default
          end

          expected_value = types[name][4]
          it "should have an typecasted value #{expected_value.inspect}" do
            @book.send(name).should == expected_value
          end
        end
      end
    end
  end
rescue LoadError => e
  describe 'do_sqlite3' do
    it 'should be required' do
      fail "SQLite3 integration specs not run! Could not load do_sqlite3: #{e}"
    end
  end
end

begin
  require 'do_postgres'

  DataMapper.setup(:postgres, 'postgres://postgres@localhost/dm_core_test')

  describe DataMapper::AutoMigrations, '.auto_migrate!' do
    before :all do
      @adapter = repository(:postgres).adapter

      DataMapper::AutoMigrator.models.clear

      @property_class = Struct.new(:name, :type, :nullable, :default, :serial)
    end

    after :all do
      DataMapper::AutoMigrator.models.clear
    end

    describe 'with postgres' do
      before :all do
        Book.auto_migrate!(:postgres)

        query = <<-EOS
          SELECT
            -- Field
            pg_attribute.attname AS "Field",
            -- Type
            CASE pg_type.typname
              WHEN 'varchar' THEN 'varchar'
              ELSE pg_type.typname
            END AS "Type",
            -- Null
            CASE WHEN pg_attribute.attnotnull THEN ''
              ELSE 'YES'
            END AS "Null",
            -- Default
            CASE pg_type.typname
              WHEN 'varchar' THEN substring(pg_attrdef.adsrc from E'^\\'(.*)\\'.*$')
              ELSE pg_attrdef.adsrc
            END AS "Default"
          FROM pg_class
            INNER JOIN pg_attribute
              ON (pg_class.oid=pg_attribute.attrelid)
            INNER JOIN pg_type
              ON (pg_attribute.atttypid=pg_type.oid)
            LEFT JOIN pg_attrdef
              ON (pg_class.oid=pg_attrdef.adrelid AND pg_attribute.attnum=pg_attrdef.adnum)
          WHERE pg_class.relname='books' AND pg_attribute.attnum >=1 AND NOT pg_attribute.attisdropped
          ORDER BY pg_attribute.attnum
        EOS

        @table_set = @adapter.query(query).inject({}) do |ts,column|
          default = column.default
          serial  = false

          if column.default == "nextval('books_serial_seq'::regclass)"
            default = nil
            serial  = true
          end

          property = @property_class.new(
            column.field,
            column.type.upcase,
            column.null == 'YES',
            default,
            serial
          )

          ts.update(property.name => property)
        end

        repository(:postgres) do
          Book.create!
          @book = Book.first
        end
      end

      types = {
        :serial      => [ Fixnum,     'INT4',          false, nil,                                                                   1,                 true  ],
        :fixnum      => [ Fixnum,     'INT4',          false, '1',                                                                   1,                 false ],
        :string      => [ String,     'VARCHAR',       false, 'default',                                                             'default',         false ],
        :date        => [ Date,       'DATE',          false, "'#{TODAY.strftime('%Y-%m-%d')}'::date",                               TODAY,             false ],
        :true_class  => [ TrueClass,  'BOOL',          false, 'true',                                                                true,              false ],
        :false_class => [ TrueClass,  'BOOL',          false, 'false',                                                               false,             false ],
        :text        => [ DM::Text,   'TEXT',          false, "'text'::text",                                                        'text',            false ],
#        :class       => [ Class,      'VARCHAR(50)',   false, 'Class',                                                               'Class',           false ],
        :big_decimal => [ BigDecimal, 'NUMERIC',       false, '1.1',                                                                 BigDecimal('1.1'), false ],
        :float       => [ Float,      'FLOAT8',        false, '1.1',                                                                 1.1,               false ],
        :date_time   => [ DateTime,   'TIMESTAMP',     false, "'#{NOW.strftime('%Y-%m-%d %H:%M:%S')}'::timestamp without time zone", NOW,               false ],
        :object      => [ Object,     'TEXT',          true,  nil,                                                                   nil,               false ],
      }

      types.each do |name,(klass,type,nullable,default,key)|
        describe "a #{klass} property" do
          it "should be created as a #{type}" do
            @table_set[name.to_s].type.should == type
          end

          it "should #{!nullable && 'not'} be nullable".squeeze(' ') do
            @table_set[name.to_s].nullable.should == nullable
          end

          it "should have a default value #{default.inspect}" do
            @table_set[name.to_s].default.should == default
          end

          expected_value = types[name][4]
          it "should have an typecasted value #{expected_value.inspect}" do
            @book.send(name).should == expected_value
          end
        end
      end
    end
  end
rescue LoadError => e
  describe 'do_sqlite3' do
    it 'should be required' do
      fail "SQLite3 integration specs not run! Could not load do_sqlite3: #{e}"
    end
  end
end