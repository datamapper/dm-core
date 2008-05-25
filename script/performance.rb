#!/usr/bin/env ruby

require File.join(File.dirname(__FILE__), '..', 'lib', 'data_mapper')

require 'benchmark'
require 'rubygems'

gem 'faker', '>= 0.3.1'
require 'faker'

gem 'activerecord', '>= 2.0.2'
require 'active_record'

socket_file = Pathname.glob(%w[
  /opt/local/var/run/mysql5/mysqld.sock
  tmp/mysqld.sock
  /tmp/mysqld.sock
  tmp/mysql.sock
  /tmp/mysql.sock
  /var/mysql/mysql.sock
]).find(&:socket?)

configuration_options = {
  :adapter => 'mysql',
  :username => 'root',
  :password => '',
  :database => 'data_mapper_1',
}

configuration_options[:socket] = socket_file unless socket_file.nil?

log_dir = DataMapper.root / 'log'
log_dir.mkdir unless log_dir.directory?

DataMapper::Logger.new(log_dir / 'dm.log', :debug)
adapter = DataMapper.setup(:default, "mysql://root@localhost/data_mapper_1?socket=#{socket_file}")

ActiveRecord::Base.logger = Logger.new(log_dir / 'ar.log')
ActiveRecord::Base.logger.level = 0

ActiveRecord::Base.establish_connection(configuration_options)

class ARExhibit < ActiveRecord::Base #:nodoc:
  set_table_name 'exhibits'
end

ARExhibit.find_by_sql('SELECT 1')

class Exhibit
  include DataMapper::Resource

  property :id,         Integer, :serial => true
  property :name,       String
  property :zoo_id,     Integer
  property :notes,      DM::Text, :lazy => true
  property :created_on, Date
#  property :updated_at, DateTime
end

touch_attributes = lambda do |exhibits|
  [*exhibits].each do |exhibit|
    exhibit.id
    exhibit.name
    exhibit.created_on
#    exhibit.updated_at
  end
end

exhibits = []

# pre-compute the insert statements and fake data compilation,
# so the benchmarks below show the actual runtime for the execute
# method, minus the setup steps
10_000.times do
  exhibits << [
#    'INSERT INTO `exhibits` (`name`, `zoo_id`, `notes`, `created_on`, `updated_at`) VALUES (?, ?, ?, ?, ?)'
    'INSERT INTO `exhibits` (`name`, `zoo_id`, `notes`, `created_on`) VALUES (?, ?, ?, ?)',
    Faker::Company.name,
    rand(10).ceil,
    Faker::Lorem.paragraphs.join($/),
    Date.today,
#    Time.now,
  ]
end

Benchmark.bmbm(60) do |x|
  # reset the exhibits
  x.report do
    Exhibit.auto_migrate!
  end

  x.report('DO.execute insert     x10,000') do
    10_000.times { |i| adapter.execute(*exhibits.at(i)) }
  end

  x.report('AR.id                 x10,000') do
    ActiveRecord::Base::uncached do
      10_000.times { touch_attributes[ARExhibit.find(1)] }
    end
  end

  x.report('DM.id                 x10,000') do
    10_000.times { touch_attributes[Exhibit.get(1)] }
  end

  x.report('AR.id                 x10,000 (cached)') do
    ActiveRecord::Base::cache do
      10_000.times { touch_attributes[ARExhibit.find(1)] }
    end
  end

  x.report('DM.id                 x10,000 (cached)') do
    repository(:default) do
      10_000.times { touch_attributes[Exhibit.get(1)] }
    end
  end

  x.report('AR.first              x10,000') do
    10_000.times { touch_attributes[ARExhibit.find(:first)] }
  end

  x.report('DM.first              x10,000') do
    10_000.times { touch_attributes[Exhibit.first] }
  end

  x.report('AR.all limit(100)     x1,000') do
    ActiveRecord::Base::uncached do
      1000.times { touch_attributes[ARExhibit.find(:all, :limit => 100)] }
    end
  end

  x.report('DM.all limit(100)     x1,000') do
    1000.times { touch_attributes[Exhibit.all(:limit => 100)] }
  end

  x.report('AR.all limit(100)     x1,000 (cached)') do
    ActiveRecord::Base::cache do
      1000.times { touch_attributes[ARExhibit.find(:all, :limit => 100)] }
    end
  end

  x.report('DM.all limit(100)     x1,000 (cached)') do
    repository(:default) do
      1000.times { touch_attributes[Exhibit.all(:limit => 100)] }
    end
  end

  x.report('AR.all limit(10,000)  x10') do
    ActiveRecord::Base::uncached do
      10.times { touch_attributes[ARExhibit.find(:all, :limit => 10_000)] }
    end
  end

  x.report('DM.all limit(10,000)  x10') do
    10.times { touch_attributes[Exhibit.all(:limit => 10_000)] }
  end

  x.report('AR.all limit(10,000)  x10 (cached)') do
    ActiveRecord::Base::cache do
      10.times { touch_attributes[ARExhibit.find(:all, :limit => 10_000)] }
    end
  end

  x.report('DM.all limit(10,000)  x10 (cached)') do
    repository(:default) do
      10.times { touch_attributes[Exhibit.all(:limit => 10_000)] }
    end
  end

  # Static, just so AR and DM are on equal footing.
  create_exhibit = {
    :name       => Faker::Company.name,
    :zoo_id     => rand(10).ceil,
    :notes      => Faker::Lorem.paragraphs.join($/),
    :created_on => Date.today,
#    :updated_at => Time.now,
  }

  x.report('AR.create             x10,000') do
    10_000.times { ARExhibit.create(create_exhibit) }
  end

  x.report('DM.create             x10,000') do
    10_000.times { Exhibit.create(create_exhibit) }
  end

  x.report('AR#update             x10,000') do
    10_000.times { e = ARExhibit.find(1); e.name = 'bob'; e.save }
  end

  x.report('DM#update             x10,000') do
    10_000.times { e = Exhibit.get(1); e.name = 'bob'; e.save }
  end

  x.report('AR#destroy            x10,000') do
    # destroy records 1 to 10,000
    (1..10_000).each { |id| ARExhibit.find(id).destroy }
  end

  x.report('DM#destroy            x10,000') do
    # destroy records 10,001 to 20,000
    (10_001..20_000).each { |id| Exhibit.get(id).destroy }
  end
end

# connection = adapter.create_connection
# command = connection.create_command("DROP TABLE exhibits")
# command.execute_non_query rescue nil
# connection.close

__END__

On an iMac Core2Duo 2.16GHz:

I don't think AR is actually caching.

~/src/dm-core > script/performance.rb
Text should not be declared inline.
Rehearsal -----------------------------------------------------------------------------------------------
ActiveRecord:id x10_000                                       3.530000   0.320000   3.850000 (  4.939399)
ActiveRecord:id(cached) x10_000                               3.540000   0.320000   3.860000 (  4.797453)
DataMapper:id x10_000                                         3.190000   0.280000   3.470000 (  4.604910)
DataMapper:id(cached) x10_000                                 0.090000   0.000000   0.090000 (  0.095606)
ActiveRecord:all limit(100) x1000                            11.880000   0.060000  11.940000 ( 12.494454)
ActiveRecord:all limit(100) (cached) x1000                   11.860000   0.060000  11.920000 ( 12.521918)
DataMapper:all limit(100) x1000                               5.020000   0.040000   5.060000 (  5.578594)
DataMapper:all limit(100) (cached) x1000                      3.040000   0.040000   3.080000 (  3.581179)
ActiveRecord:all limit(10,000) x10                           12.040000   0.050000  12.090000 ( 12.243110)
ActiveRecord:all limit(10,000) (cached) x10                  12.140000   0.040000  12.180000 ( 12.339861)
DataMapper:all limit(10,000) x10                              5.740000   0.040000   5.780000 (  5.788256)
DataMapper:all limit(10,000) (cached) x10                     3.850000   0.020000   3.870000 (  3.874642)
------------------------------------------------------------------------------------- total: 77.190000sec

                                                                  user     system      total        real
ActiveRecord:id x10_000                                       3.480000   0.320000   3.800000 (  4.701110)
ActiveRecord:id(cached) x10_000                               3.480000   0.310000   3.790000 (  4.701436)
DataMapper:id x10_000                                         3.170000   0.270000   3.440000 (  4.375630)
DataMapper:id(cached) x10_000                                 0.100000   0.000000   0.100000 (  0.097554)
ActiveRecord:all limit(100) x1000                            11.410000   0.060000  11.470000 ( 11.993949)
ActiveRecord:all limit(100) (cached) x1000                   11.410000   0.050000  11.460000 ( 11.998727)
DataMapper:all limit(100) x1000                               5.060000   0.040000   5.100000 (  5.608384)
DataMapper:all limit(100) (cached) x1000                      3.020000   0.040000   3.060000 (  3.554985)
ActiveRecord:all limit(10,000) x10                           12.170000   0.040000  12.210000 ( 12.370468)
ActiveRecord:all limit(10,000) (cached) x10                  12.180000   0.040000  12.220000 ( 12.371510)
DataMapper:all limit(10,000) x10                              5.450000   0.020000   5.470000 (  5.480993)
DataMapper:all limit(10,000) (cached) x10                     3.130000   0.020000   3.150000 (  3.160792)

On a MacBook Air Core2Duo 1.6GHz (many performance optimizations since the run above)

~/src/dm-core > script/performance.rb
Rehearsal -----------------------------------------------------------------------------------------------
AR.id                 x10,000                                11.290000   0.420000  11.710000 ( 14.845046)
DM.id                 x10,000                                 5.010000   0.480000   5.490000 (  8.738212)
AR.id                 x10,000 (cached)                       12.300000   0.520000  12.820000 ( 16.585108)
DM.id                 x10,000 (cached)                        0.450000   0.000000   0.450000 (  0.474010)
AR.all limit(100)     x1,000                                  3.340000   0.080000   3.420000 (  4.554041)
DM.all limit(100)     x1,000                                  1.420000   0.050000   1.470000 (  1.743724)
AR.all limit(100)     x1,000 (cached)                         3.450000   0.070000   3.520000 (  3.937980)
DM.all limit(100)     x1,000 (cached)                         1.070000   0.050000   1.120000 (  1.390889)
AR.all limit(10,000)  x10                                     0.020000   0.000000   0.020000 (  0.031253)
DM.all limit(10,000)  x10                                     0.020000   0.000000   0.020000 (  0.017896)
AR.all limit(10,000)  x10 (cached)                            0.030000   0.000000   0.030000 (  0.032688)
DM.all limit(10,000)  x10 (cached)                            0.010000   0.000000   0.010000 (  0.013167)
AR.create             x10,000                                21.390000   1.290000  22.680000 ( 28.519556)
DM.create             x10,000                                20.090000   0.630000  20.720000 ( 28.822219)
AR.update             x10,000                                25.450000   1.660000  27.110000 ( 33.040779)
DM.update             x10,000                                 6.550000   0.780000   7.330000 ( 10.467941)
------------------------------------------------------------------------------------ total: 117.920000sec

                                                                  user     system      total        real
AR.id                 x10,000                                11.320000   0.420000  11.740000 ( 13.907577)
DM.id                 x10,000                                 4.510000   0.410000   4.920000 (  6.611278)
AR.id                 x10,000 (cached)                       11.680000   0.440000  12.120000 ( 14.792082)
DM.id                 x10,000 (cached)                        0.380000   0.010000   0.390000 (  0.384611)
AR.all limit(100)     x1,000                                 25.010000   0.200000  25.210000 ( 25.954076)
DM.all limit(100)     x1,000                                 10.370000   0.090000  10.460000 ( 11.558341)
AR.all limit(100)     x1,000 (cached)                        28.390000   0.350000  28.740000 ( 30.870503)
DM.all limit(100)     x1,000 (cached)                         7.760000   0.110000   7.870000 (  9.211700)
AR.all limit(10,000)  x10                                    27.850000   0.240000  28.090000 ( 28.510220)
DM.all limit(10,000)  x10                                    10.970000   0.040000  11.010000 ( 11.042093)
AR.all limit(10,000)  x10 (cached)                           29.230000   0.170000  29.400000 ( 29.816547)
DM.all limit(10,000)  x10 (cached)                            7.470000   0.030000   7.500000 (  7.520561)
AR.create             x10,000                                21.700000   1.400000  23.100000 ( 27.188424)
DM.create             x10,000                                24.380000   0.550000  24.930000 ( 29.439910)
AR.update             x10,000                                30.670000   1.910000  32.580000 ( 39.227956)
DM.update             x10,000                                 8.290000   0.950000   9.240000 ( 12.912708)
