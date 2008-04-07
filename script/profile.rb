#!/usr/bin/env ruby

require 'pathname'
require Pathname(__FILE__).dirname.expand_path.parent + 'lib/data_mapper/support/kernel'

require __DIR__.parent + 'lib/data_mapper'

require 'ruby-prof'

OUTPUT = __DIR__.parent + 'profile_results.txt'

SOCKET_FILE = Pathname.glob(%w[
  /opt/local/var/run/mysql5/mysqld.sock
  tmp/mysqld.sock
  tmp/mysql.sock
]).find(&:socket?)

DataMapper::Logger.new(__DIR__.parent + 'log/dm.log', :debug)
DataMapper.setup(:default, "mysql://root@localhost/data_mapper_1?socket=#{SOCKET_FILE}")

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

# RubyProf, making profiling Ruby pretty since 1899!
def profile(&b)
  result  = RubyProf.profile &b
  printer = RubyProf::FlatPrinter.new(result)
  printer.print(OUTPUT.open('w+'))
end

profile do
  10_000.times { touch_attributes[Exhibit.get(1)] }

#  repository(:default) do
#    10_000.times { touch_attributes[Exhibit.get(1)] }
#  end
#
#  1000.times { touch_attributes[Exhibit.all(:limit => 100)] }
#
#  repository(:default) do
#    1000.times { touch_attributes[Exhibit.all(:limit => 100)] }
#  end
#
#  10.times { touch_attributes[Exhibit.all(:limit => 10_000)] }
#
#  repository(:default) do
#    10.times { touch_attributes[Exhibit.all(:limit => 10_000)] }
#  end
end

puts "Done!"
