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
ActiveRecord:id x10_000                                       3.490000   0.330000   3.820000 (  4.766316)
ActiveRecord:id(cached) x10_000                               3.500000   0.320000   3.820000 (  4.763179)
DataMapper:id x10_000                                         3.770000   0.290000   4.060000 (  5.036568)
DataMapper:id(cached) x10_000                                 3.380000   0.280000   3.660000 (  4.626784)
ActiveRecord:all limit(100) x1000                            12.490000   0.070000  12.560000 ( 13.244165)
ActiveRecord:all limit(100) (cached) x1000                   12.520000   0.070000  12.590000 ( 13.147605)
DataMapper:all limit(100) x1000                               9.900000   0.070000   9.970000 ( 10.925294)
DataMapper:all limit(100) (cached) x1000                      7.740000   0.060000   7.800000 (  8.532725)
ActiveRecord:all limit(10,000) x10                           12.880000   0.080000  12.960000 ( 13.152890)
ActiveRecord:all limit(10,000) (cached) x10                  12.950000   0.060000  13.010000 ( 13.187061)
DataMapper:all limit(10,000) x10                             11.680000   0.060000  11.740000 ( 11.775914)
DataMapper:all limit(10,000) (cached) x10                     8.980000   0.030000   9.010000 (  9.063474)
------------------------------------------------------------------------------------ total: 105.000000sec

                                                                  user     system      total        real
ActiveRecord:id x10_000                                       3.460000   0.320000   3.780000 (  4.696250)
ActiveRecord:id(cached) x10_000                               3.460000   0.330000   3.790000 (  4.704204)
DataMapper:id x10_000                                         3.770000   0.280000   4.050000 (  4.997452)
DataMapper:id(cached) x10_000                                 3.400000   0.280000   3.680000 (  4.617069)
ActiveRecord:all limit(100) x1000                            12.050000   0.070000  12.120000 ( 12.702236)
ActiveRecord:all limit(100) (cached) x1000                   12.040000   0.060000  12.100000 ( 12.664863)
DataMapper:all limit(100) x1000                               9.490000   0.060000   9.550000 ( 10.112563)
DataMapper:all limit(100) (cached) x1000                      7.310000   0.060000   7.370000 (  7.921475)
ActiveRecord:all limit(10,000) x10                           12.780000   0.040000  12.820000 ( 12.980122)
ActiveRecord:all limit(10,000) (cached) x10                  12.820000   0.070000  12.890000 ( 13.077420)
DataMapper:all limit(10,000) x10                             10.140000   0.030000  10.170000 ( 10.265600)
DataMapper:all limit(10,000) (cached) x10                     7.570000   0.020000   7.590000 (  7.601997)
