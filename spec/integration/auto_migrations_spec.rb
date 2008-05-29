require 'pathname'
require Pathname(__FILE__).dirname.expand_path.parent + 'spec_helper'
require 'ostruct'

TODAY   = Date.today
NOW     = DateTime.now

TIME_STRING_1 = '2007-04-21 04:14:12'
TIME_STRING_2 = '2007-04-21 04:14:12.1'
TIME_STRING_3 = '2007-04-21 04:14:12.01'
TIME_STRING_4 = '2007-04-21 04:14:12.123456'

TIME_1 = Time.parse(TIME_STRING_1)
TIME_2 = Time.parse(TIME_STRING_2)
TIME_3 = Time.parse(TIME_STRING_3)
TIME_4 = Time.parse(TIME_STRING_4)

class Book
  include DataMapper::Resource

  property :serial,      Integer,    :serial => true
  property :fixnum,      Integer,    :nullable => false, :default => 1
  property :string,      String,     :nullable => false, :default => 'default'
  property :empty,       String,     :nullable => false, :default => ''
  property :date,        Date,       :nullable => false, :default => TODAY,                                           :index => :date_date_time, :unique_index => :date_float
  property :true_class,  TrueClass,  :nullable => false, :default => true
  property :false_class, TrueClass,  :nullable => false, :default => false
  property :text,        DM::Text,   :nullable => false, :default => 'text'
#  property :class,       Class,      :nullable => false, :default => Class  # FIXME: Class types cause infinite recursions in Resource
  property :big_decimal, BigDecimal, :nullable => false, :default => BigDecimal('1.1'), :scale => 2, :precision => 1
  property :float,       Float,      :nullable => false, :default => 1.1,               :scale => 2, :precision => 1, :unique_index => :date_float
  property :date_time,   DateTime,   :nullable => false, :default => NOW,                                             :index => [:date_date_time, true]
  property :time_1,      Time,       :nullable => false, :default => TIME_1,                                          :unique_index => true
  property :time_2,      Time,       :nullable => false, :default => TIME_2
  property :time_3,      Time,       :nullable => false, :default => TIME_3
  property :time_4,      Time,       :nullable => false, :default => TIME_4
  property :object,      Object,     :nullable => true                       # FIXME: cannot supply a default for Object
end

if HAS_SQLITE3
  describe DataMapper::AutoMigrations, '.auto_migrate! with sqlite3' do
    before :all do
      @adapter = repository(:sqlite3).adapter

      DataMapper::Resource.descendents.clear

      @property_class = Struct.new(:name, :type, :nullable, :default, :serial)
    end

    after :all do
      DataMapper::Resource.descendents.clear
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

        @index_list = @adapter.query('PRAGMA index_list("books")')

        # bypass DM to create the record using only the column default values
        @adapter.execute('INSERT INTO books (serial) VALUES (1)')

        repository(:sqlite3) do
          @book = Book.first
        end
      end

      types = {
        :serial      => [ Integer,    'INTEGER',      false, nil,                               1,                 true  ],
        :fixnum      => [ Integer,    'INTEGER',      false, '1',                               1,                 false ],
        :string      => [ String,     'VARCHAR(50)',  false, 'default',                         'default',         false ],
        :empty       => [ String,     'VARCHAR(50)',  false, '',                                ''       ,         false ],
        :date        => [ Date,       'DATE',         false, TODAY.strftime('%Y-%m-%d'),        TODAY,             false ],
        :true_class  => [ TrueClass,  'BOOLEAN',      false, 't',                               true,              false ],
        :false_class => [ TrueClass,  'BOOLEAN',      false, 'f',                               false,             false ],
        :text        => [ DM::Text,   'TEXT',         false, 'text',                            'text',            false ],
#        :class       => [ Class,      'VARCHAR(50)',  false, 'Class',                           'Class',           false ],
        :big_decimal => [ BigDecimal, 'DECIMAL(2,1)', false, '1.1',                             BigDecimal('1.1'), false ],
        :float       => [ Float,      'FLOAT(2,1)',   false, '1.1',                             1.1,               false ],
        :date_time   => [ DateTime,   'DATETIME',     false, NOW.strftime('%Y-%m-%d %H:%M:%S'), NOW,               false ],
        :time_1      => [ Time,       'TIMESTAMP',    false, TIME_STRING_1,                     TIME_1,            false ],
#SQLite pads out the microseconds to the full 6 digits no matter what the value is - we simply pad up the zeros needed
        :time_2      => [ Time,       'TIMESTAMP',    false, TIME_STRING_2.dup << '00000',      TIME_2,            false ],
        :time_3      => [ Time,       'TIMESTAMP',    false, TIME_STRING_3.dup << '0000',       TIME_3,            false ],
        :time_4      => [ Time,       'TIMESTAMP',    false, TIME_STRING_4,                     TIME_4,            false ],
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

      it 'should have 4 indexes: 2 non-unique index, 2 unique index' do
        @index_list.size.should == 4
        @index_list[0].name.should == 'unique_index_books_date_float'
        @index_list[0].unique.should == 1
        @index_list[1].name.should == 'unique_index_books_time_1'
        @index_list[1].unique.should == 1
        @index_list[2].name.should == 'index_books_date_date_time'
        @index_list[2].unique.should == 0
        @index_list[3].name.should == 'index_books_date_time'
        @index_list[3].unique.should == 0
      end

    end
  end
end

if HAS_MYSQL
  describe DataMapper::AutoMigrations, '.auto_migrate! with mysql' do
    before :all do
      @adapter = repository(:mysql).adapter

      DataMapper::Resource.descendents.clear

      @property_class = Struct.new(:name, :type, :nullable, :default, :serial)
    end

    after :all do
      DataMapper::Resource.descendents.clear
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

        @index_list = @adapter.query('SHOW INDEX FROM books')

        # bypass DM to create the record using only the column default values
        @adapter.execute('INSERT INTO books (serial, text) VALUES (1, \'text\')')

        repository(:mysql) do
          @book = Book.first
        end
      end

      types = {
        :serial      => [ Integer,    'INT(11)',      false, nil,                                  1,                 true  ],
        :fixnum      => [ Integer,    'INT(11)',      false, '1',                                  1,                 false ],
        :string      => [ String,     'VARCHAR(50)',  false, 'default',                            'default',         false ],
        :empty       => [ String,     'VARCHAR(50)',  false, '',                                   '',                false ],
        :date        => [ Date,       'DATE',         false, TODAY.strftime('%Y-%m-%d'),           TODAY,             false ],
        :true_class  => [ TrueClass,  'TINYINT(1)',   false, '1',                                  true,              false ],
        :false_class => [ TrueClass,  'TINYINT(1)',   false, '0',                                  false,             false ],
        :text        => [ DM::Text,   'TEXT',         false, nil,                                  'text',            false ],
#        :class       => [ Class,      'VARCHAR(50)',  false, 'Class',                              'Class',           false ],
        :big_decimal => [ BigDecimal, 'DECIMAL(2,1)', false, '1.1',                                BigDecimal('1.1'), false ],
        :float       => [ Float,      'FLOAT(2,1)',   false, '1.1',                                1.1,               false ],
        :date_time   => [ DateTime,   'DATETIME',     false, NOW.strftime('%Y-%m-%d %H:%M:%S'),    NOW,               false ],
        :time_1      => [ Time,       'TIMESTAMP',    false, TIME_1.strftime('%Y-%m-%d %H:%M:%S'), TIME_1,            false ],
        :time_2      => [ Time,       'TIMESTAMP',    false, TIME_2.strftime('%Y-%m-%d %H:%M:%S'), TIME_2,            false ],
        :time_3      => [ Time,       'TIMESTAMP',    false, TIME_3.strftime('%Y-%m-%d %H:%M:%S'), TIME_3 ,           false ],
        :time_4      => [ Time,       'TIMESTAMP',    false, TIME_4.strftime('%Y-%m-%d %H:%M:%S'), TIME_4 ,           false ],
        :object      => [ Object,     'TEXT',         true,  nil,                                  nil,               false ],
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
            if DateTime == klass || Time == klass # mysql doesn't support microsecond
              @book.attribute_get(name).to_s.should == expected_value.to_s
            else
              @book.attribute_get(name).should == expected_value
            end
          end
        end
      end

      it 'should have 4 indexes: 2 non-unique index, 2 unique index' do
        pending do
          # TODO
          @index_list[0].Key_name.should == 'unique_index_books_date_float'
          @index_list[0].Non_unique.should == 0
          @index_list[1].Key_name.should == 'unique_index_books_time_1'
          @index_list[1].Non_unique.should == 0
          @index_list[2].Key_name.should == 'index_books_date_date_time'
          @index_list[2].Non_unique.should == 1
          @index_list[3].Key_name.should == 'index_books_date_time'
          @index_list[3].Non_unique.should == 1
        end
      end
    end
  end
end

if HAS_POSTGRES
  describe DataMapper::AutoMigrations, '.auto_migrate! with postgres' do
    before :all do
      @adapter = repository(:postgres).adapter

      DataMapper::Resource.descendents.clear

      @property_class = Struct.new(:name, :type, :nullable, :default, :serial)
    end

    after :all do
      DataMapper::Resource.descendents.clear
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
        :serial      => [ Integer,    'INT4',        false, nil,                                                                   1,                 true  ],
        :fixnum      => [ Integer,    'INT4',        false, '1',                                                                   1,                 false ],
        :string      => [ String,     'VARCHAR',     false, "'default'::character varying",                                        'default',         false ],
        :empty       => [ String,     'VARCHAR',     false, "''::character varying",                                               '',                false ],
        :date        => [ Date,       'DATE',        false, "'#{TODAY.strftime('%Y-%m-%d')}'::date",                               TODAY,             false ],
        :true_class  => [ TrueClass,  'BOOL',        false, 'true',                                                                true,              false ],
        :false_class => [ TrueClass,  'BOOL',        false, 'false',                                                               false,             false ],
        :text        => [ DM::Text,   'TEXT',        false, "'text'::text",                                                        'text',            false ],
#        :class       => [ Class,      'VARCHAR(50)', false, 'Class',                                                               'Class',           false ],
        :big_decimal => [ BigDecimal, 'NUMERIC',     false, '1.1',                                                                 BigDecimal('1.1'), false ],
        :float       => [ Float,      'FLOAT8',      false, '1.1',                                                                 1.1,               false ],
        :date_time   => [ DateTime,   'TIMESTAMP',   false, "'#{NOW.strftime('%Y-%m-%d %H:%M:%S')}'::timestamp without time zone", NOW,               false ],
        :time_1      => [ Time,       'TIMESTAMP',   false, "'" << TIME_STRING_1.dup << "'::timestamp without time zone",          TIME_1,            false ],
#The weird zero here is simply because postgresql seems to want to store .10 instead of .1 for this one
#affects anything with an exact tenth of a second (i.e. .1, .2, .3, ...)
        :time_2      => [ Time,       'TIMESTAMP',   false, "'" << TIME_STRING_2.dup << "0'::timestamp without time zone",         TIME_2,            false ],
        :time_3      => [ Time,       'TIMESTAMP',   false, "'" << TIME_STRING_3.dup << "'::timestamp without time zone",          TIME_3,            false ],
        :time_4      => [ Time,       'TIMESTAMP',   false, "'" << TIME_STRING_4.dup << "'::timestamp without time zone",          TIME_4,            false ],
        :object      => [ Object,     'TEXT',        true,  nil,                                                                   nil,               false ],
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

      it 'should have 4 indexes: 2 non-unique index, 2 unique index' do
        pending 'TODO'
      end
    end
  end
end
