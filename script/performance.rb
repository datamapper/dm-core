#!/usr/bin/env ruby

require 'pathname'
require Pathname(__FILE__).dirname.expand_path.parent + 'lib/data_mapper/support/kernel'

require 'benchmark'
require 'rubygems'
require 'active_record'

socket_file = Pathname.glob(%w[
  /opt/local/var/run/mysql5/mysqld.sock
  tmp/mysqld.sock
  tmp/mysql.sock
]).find(&:socket?)

configuration_options = {
  :adapter => 'mysql',
  :username => 'root',
  :password => '',
  :database => 'data_mapper_1'
}

configuration_options[:socket] = socket_file unless socket_file.nil?

ActiveRecord::Base.logger = Logger.new(__DIR__.parent + 'log/ar.log')
ActiveRecord::Base.logger.level = 0

ActiveRecord::Base.establish_connection(configuration_options)

class ARExhibit < ActiveRecord::Base #:nodoc:
  set_table_name 'exhibits'
end

ARExhibit.find_by_sql('SELECT 1')

require __DIR__.parent + 'lib/data_mapper'

DataMapper::Logger.new(__DIR__.parent + 'log/dm.log', :debug)

DataMapper.setup(:default, "mysql://root@localhost/data_mapper_1?socket=#{socket_file}")

class Exhibit
  include DataMapper::Resource
  
  property :id, Fixnum, :serial => true
  property :name, String
  property :zoo_id, Fixnum
  property :notes, String, :lazy => true
  property :created_on, Date
  property :updated_at, DateTime
  
end

touch_attributes = lambda do |exhibits|
  [*exhibits].each do |exhibit|
    exhibit.id
    exhibit.name
    exhibit.created_on
    exhibit.updated_at
  end
end

# report_for_active_record = lambda do |runner, message, iterations, block|
#   [:uncached, :cache].each do |variant|
#     ActiveRecord::Base.send(variant) do
#       runner.report(message + " #{(variant)}") do
#         iterations.times do
#           touch_attributes[block.call]
#         end
#       end
#     end
#   end
# end
# 
# report_for_data_mapper = lambda do |runner, message, iterations, block|
#   [:uncached, :cache].each do |variant|
#     if variant == :cache
#       repository(:default) { runner.report(message + " #{(variant)}", &block) }
#     else
#       runner.report(message + " #{(variant)}", &block)
#     end
#   end
# end

Benchmark::bmbm(60) do |x|
  
  x.report('ActiveRecord:id x10_000') do
    ActiveRecord::Base::uncached do
      10_000.times { touch_attributes[ARExhibit.find(1)] }
    end
  end

  x.report('ActiveRecord:id(cached) x10_000') do
    ActiveRecord::Base::cache do
      10_000.times { touch_attributes[ARExhibit.find(1)] }
    end
  end

  x.report('DataMapper:id x10_000') do
    10_000.times { touch_attributes[Exhibit.get(1)] }
  end

  x.report('DataMapper:id(cached) x10_000') do
    repository(:default) do
      10_000.times { touch_attributes[Exhibit.get(1)] }
    end
  end

  x.report('ActiveRecord:all limit(100) x1000') do
    ActiveRecord::Base::uncached do
      1000.times { touch_attributes[ARExhibit.find(:all, :limit => 100)] }
    end
  end

  x.report('ActiveRecord:all limit(100) (cached) x1000') do
    ActiveRecord::Base::cache do
      1000.times { touch_attributes[ARExhibit.find(:all, :limit => 100)] }
    end
  end

  x.report('DataMapper:all limit(100) x1000') do
    1000.times { touch_attributes[Exhibit.all(:limit => 100)] }
  end

  x.report('DataMapper:all limit(100) (cached) x1000') do
    repository(:default) do
      1000.times { touch_attributes[Exhibit.all(:limit => 100)] }
    end
  end
  
  x.report('ActiveRecord:all limit(10,000) x10') do
    ActiveRecord::Base::uncached do
      10.times { touch_attributes[ARExhibit.find(:all, :limit => 10_000)] }
    end
  end

  x.report('ActiveRecord:all limit(10,000) (cached) x10') do
    ActiveRecord::Base::cache do
      10.times { touch_attributes[ARExhibit.find(:all, :limit => 10_000)] }
    end
  end

  x.report('DataMapper:all limit(10,000) x10') do
    10.times { touch_attributes[Exhibit.all(:limit => 10_000)] }
  end

  x.report('DataMapper:all limit(10,000) (cached) x10') do
    repository(:default) do
      10.times { touch_attributes[Exhibit.all(:limit => 10_000)] }
    end
  end
    
end

__END__

On an iMac Core2Duo 2.16Ghz:

I don't think AR is actually caching.

~/src/dm-core > script/performance.rb 
Text should not be declared inline.
Rehearsal -----------------------------------------------------------------------------------------------
ActiveRecord:id x10_000                                       3.660000   0.340000   4.000000 (  5.109171)
ActiveRecord:id(cached) x10_000                               3.710000   0.320000   4.030000 (  5.005374)
DataMapper:id x10_000                                         3.750000   0.290000   4.040000 (  4.991087)
DataMapper:id(cached) x10_000                                 3.360000   0.280000   3.640000 (  4.593049)
ActiveRecord:all limit(100) x1000                            12.470000   0.080000  12.550000 ( 13.208246)
ActiveRecord:all limit(100) (cached) x1000                   12.460000   0.070000  12.530000 ( 13.126612)
DataMapper:all limit(100) x1000                               9.780000   0.070000   9.850000 ( 10.407024)
DataMapper:all limit(100) (cached) x1000                      7.560000   0.060000   7.620000 (  8.199876)
ActiveRecord:all limit(10,000) x10                           12.840000   0.060000  12.900000 ( 13.092556)
ActiveRecord:all limit(10,000) (cached) x10                  12.910000   0.040000  12.950000 ( 13.168203)
DataMapper:all limit(10,000) x10                             10.030000   0.030000  10.060000 ( 10.081265)
DataMapper:all limit(10,000) (cached) x10                     8.340000   0.030000   8.370000 (  8.414619)
------------------------------------------------------------------------------------ total: 102.540000sec

                                                                  user     system      total        real
ActiveRecord:id x10_000                                       3.620000   0.320000   3.940000 (  4.941440)
ActiveRecord:id(cached) x10_000                               3.650000   0.340000   3.990000 (  5.388042)
DataMapper:id x10_000                                         3.770000   0.290000   4.060000 (  5.488544)
DataMapper:id(cached) x10_000                                 3.410000   0.290000   3.700000 (  4.816295)
ActiveRecord:all limit(100) x1000                            12.070000   0.070000  12.140000 ( 12.720874)
ActiveRecord:all limit(100) (cached) x1000                   12.070000   0.070000  12.140000 ( 13.057080)
DataMapper:all limit(100) x1000                               9.380000   0.060000   9.440000 ( 10.027574)
DataMapper:all limit(100) (cached) x1000                      7.210000   0.060000   7.270000 (  7.854531)
ActiveRecord:all limit(10,000) x10                           12.760000   0.040000  12.800000 ( 12.972975)
ActiveRecord:all limit(10,000) (cached) x10                  12.760000   0.060000  12.820000 ( 13.009056)
DataMapper:all limit(10,000) x10                              9.980000   0.050000  10.030000 ( 10.087230)
DataMapper:all limit(10,000) (cached) x10                     7.460000   0.030000   7.490000 (  7.526797)