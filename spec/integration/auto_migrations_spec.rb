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
  property :empty,       String,     :nullable => false, :default => ''
  property :date,        Date,       :nullable => false, :default => TODAY
  property :true_class,  TrueClass,  :nullable => false, :default => true
  property :false_class, TrueClass,  :nullable => false, :default => false
  property :text,        DM::Text,   :nullable => false, :default => 'text'
#  property :class,       Class,      :nullable => false, :default => Class  # FIXME: Class types cause infinite recursions in Resource
  property :big_decimal, BigDecimal, :nullable => false, :default => BigDecimal('1.1'), :precision => 2, :scale => 1
  property :float,       Float,      :nullable => false, :default => 1.1
  property :date_time,   DateTime,   :nullable => false, :default => NOW
  property :object,      Object,     :nullable => true                       # FIXME: cannot supply a default for Object
end

begin
  gem 'do_sqlite3', '=0.9.0'
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

        # bypass DM to create the record using only the column default values
        @adapter.execute('INSERT INTO books (serial) VALUES (1)')

        repository(:sqlite3) do
          @book = Book.first
        end
      end

      types = {
        :serial      => [ Fixnum,     'INTEGER',      false, nil,                               1,                 true  ],
        :fixnum      => [ Fixnum,     'INTEGER',      false, '1',                               1,                 false ],
        :string      => [ String,     'VARCHAR(50)',  false, 'default',                         'default',         false ],
        :empty       => [ String,     'VARCHAR(50)',  false, '',                                ''       ,         false ],
        :date        => [ Date,       'DATE',         false, TODAY.strftime('%Y-%m-%d'),        TODAY,             false ],
        :true_class  => [ TrueClass,  'BOOLEAN',      false, 't',                               true,              false ],
        :false_class => [ TrueClass,  'BOOLEAN',      false, 'f',                               false,             false ],
        :text        => [ DM::Text,   'TEXT',         false, 'text',                            'text',            false ],
#        :class       => [ Class,      'VARCHAR(50)',  false, 'Class',                           'Class',           false ],
        :big_decimal => [ BigDecimal, 'DECIMAL(2,1)', false, '1.1',                             BigDecimal('1.1'), false ],
        :float       => [ Float,      'FLOAT',        false, '1.1',                             1.1,               false ],
        :date_time   => [ DateTime,   'DATETIME',     false, NOW.strftime('%Y-%m-%d %H:%M:%S'), NOW,               false ],
        :object      => [ Object,     'TEXT',         true,  nil,                               nil,               false ],
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
          it 'should properly typecast value' do

            if DateTime == klass
              @book.attribute_get(name).to_s.should == expected_value.to_s
            else
              @book.attribute_get(name).should == expected_value
            end
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
  gem 'do_mysql', '=0.9.0'
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
            column.type.upcase == 'TEXT' ? nil : column.default,
            column.extra.split.include?('auto_increment')
          )

          ts.update(property.name => property)
        end

        # bypass DM to create the record using only the column default values
        @adapter.execute('INSERT INTO books (serial, text) VALUES (1, \'text\')')

        repository(:mysql) do
          @book = Book.first
        end
      end

      types = {
        :serial      => [ Fixnum,     'INT(11)',       false, nil,                               1,                 true  ],
        :fixnum      => [ Fixnum,     'INT(11)',       false, '1',                               1,                 false ],
        :string      => [ String,     'VARCHAR(50)',   false, 'default',                         'default',         false ],
        :empty       => [ String,     'VARCHAR(50)',   false, '',                                '',                false ],
        :date        => [ Date,       'DATE',          false, TODAY.strftime('%Y-%m-%d'),        TODAY,             false ],
        :true_class  => [ TrueClass,  'TINYINT(1)',    false, '1',                               true,              false ],
        :false_class => [ TrueClass,  'TINYINT(1)',    false, '0',                               false,             false ],
        :text        => [ DM::Text,   'TEXT',          false, nil,                               'text',            false ],
#        :class       => [ Class,      'VARCHAR(50)',   false, 'Class',                           'Class',           false ],
        :big_decimal => [ BigDecimal, 'DECIMAL(2,1)',  false, '1.1',                             BigDecimal('1.1'), false ],
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
          it 'should properly typecast value' do
            if DateTime == klass
              @book.attribute_get(name).to_s.should == expected_value.to_s
            else
              @book.attribute_get(name).should == expected_value
            end
          end
        end
      end
    end
  end
rescue LoadError => e
  describe 'do_mysql' do
    it 'should be required' do
      fail "MySQL integration specs not run! Could not load do_mysql: #{e}"
    end
  end
end

begin
  gem 'do_postgres', '=0.9.0'
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
            pg_attrdef.adsrc AS "Default"
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

        # bypass DM to create the record using only the column default values
        @adapter.execute('INSERT INTO books (serial) VALUES (1)')

        repository(:postgres) do
          @book = Book.first
        end
      end

      types = {
        :serial      => [ Fixnum,     'INT4',          false, nil,                                                                   1,                 true  ],
        :fixnum      => [ Fixnum,     'INT4',          false, '1',                                                                   1,                 false ],
        :string      => [ String,     'VARCHAR',       false, "'default'::character varying",                                        'default',         false ],
        :empty       => [ String,     'VARCHAR',       false, "''::character varying",                                               '',                false ],
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
        describe "a #{DataMapper::Inflection.classify(name.to_s)} property" do
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
          it 'should properly typecast value' do
            if DateTime == klass
              @book.attribute_get(name).to_s.should == expected_value.to_s
            else
              @book.attribute_get(name).should == expected_value
            end
          end
        end
      end
    end
  end
rescue LoadError => e
  describe 'do_postgres' do
    it 'should be required' do
      fail "PostgreSQL integration specs not run! Could not load do_postgres: #{e}"
    end
  end
end
