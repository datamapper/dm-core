#!/usr/bin/env ruby

require 'pathname'
require Pathname(__FILE__).dirname.expand_path.parent + 'lib/data_mapper/support/kernel'

require __DIR__.parent + 'lib/data_mapper'

require 'benchmark'
require 'rubygems'

require 'faker'
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

# connection = adapter.create_connection
# command = connection.create_command <<-EOS.compress_lines
#   CREATE TABLE `exhibits` (
#     `id` INTEGER(11) NOT NULL AUTO_INCREMENT,
#     `name` VARCHAR(50),
#     `zoo_id` INTEGER(11),
#     `notes` TEXT,
#     `created_on` DATE,
#     `updated_at` TIMESTAMP NOT NULL,
#     PRIMARY KEY(`id`)
#   )
# EOS
#
# command.execute_non_query rescue nil

# command = connection.create_command <<-EOS.compress_lines
#   INSERT INTO `exhibits` (`name`, `zoo_id`, `notes`, `created_on`, `updated_at`) VALUES (?, ?, ?, ?, ?)
# EOS
#
# 1000.times do
#   command.execute_non_query(
#     Faker::Company.name,
#     rand(10).ceil,
#     Faker::Lorem.paragraphs.join($/),
#     Date::today,
#     Time::now
#   )
# end
#
# connection.close

ActiveRecord::Base.logger = Logger.new(__DIR__.parent + 'log/ar.log')
ActiveRecord::Base.logger.level = 0

ActiveRecord::Base.establish_connection(configuration_options)

class ARExhibit < ActiveRecord::Base #:nodoc:
  set_table_name 'exhibits'
end

ARExhibit.find_by_sql('SELECT 1')

DataMapper::Logger.new(__DIR__.parent + 'log/dm.log', :debug)
adapter = DataMapper.setup(:default, "mysql://root@localhost/data_mapper_1?socket=#{socket_file}")

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

# connection = adapter.create_connection
# command = connection.create_command("DROP TABLE exhibits")
# command.execute_non_query rescue nil
# connection.close

__END__

On an iMac Core2Duo 2.16Ghz:

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

