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
ActiveRecord:id x10_000                                       3.650000   0.330000   3.980000 (  5.065648)
ActiveRecord:id(cached) x10_000                               3.720000   0.320000   4.040000 (  5.118424)
DataMapper:id x10_000                                         3.270000   0.290000   3.560000 (  4.538257)
DataMapper:id(cached) x10_000                                 0.160000   0.000000   0.160000 (  0.167852)
ActiveRecord:all limit(100) x1000                            12.510000   0.070000  12.580000 ( 13.245487)
ActiveRecord:all limit(100) (cached) x1000                   12.530000   0.080000  12.610000 ( 13.239177)
DataMapper:all limit(100) x1000                               5.360000   0.060000   5.420000 (  5.969965)
DataMapper:all limit(100) (cached) x1000                      3.110000   0.040000   3.150000 (  3.691300)
ActiveRecord:all limit(10,000) x10                           12.850000   0.070000  12.920000 ( 13.088399)
ActiveRecord:all limit(10,000) (cached) x10                  12.920000   0.030000  12.950000 ( 13.141124)
DataMapper:all limit(10,000) x10                              5.820000   0.030000   5.850000 (  5.916424)
DataMapper:all limit(10,000) (cached) x10                     3.840000   0.020000   3.860000 (  3.896749)
------------------------------------------------------------------------------------- total: 81.080000sec

                                                                  user     system      total        real
ActiveRecord:id x10_000                                       3.620000   0.330000   3.950000 (  4.925535)
ActiveRecord:id(cached) x10_000                               3.610000   0.330000   3.940000 (  4.906755)
DataMapper:id x10_000                                         3.300000   0.290000   3.590000 (  4.561925)
DataMapper:id(cached) x10_000                                 0.110000   0.000000   0.110000 (  0.111308)
ActiveRecord:all limit(100) x1000                            12.070000   0.070000  12.140000 ( 12.863351)
ActiveRecord:all limit(100) (cached) x1000                   12.060000   0.080000  12.140000 ( 12.745164)
DataMapper:all limit(100) x1000                               5.360000   0.060000   5.420000 (  5.999554)
DataMapper:all limit(100) (cached) x1000                      3.160000   0.040000   3.200000 (  3.735549)
ActiveRecord:all limit(10,000) x10                           12.720000   0.070000  12.790000 ( 12.995206)
ActiveRecord:all limit(10,000) (cached) x10                  12.730000   0.040000  12.770000 ( 12.966406)
DataMapper:all limit(10,000) x10                              5.730000   0.020000   5.750000 (  6.112376)
DataMapper:all limit(10,000) (cached) x10                     3.310000   0.020000   3.330000 (  3.459828)