#!/usr/bin/env ruby

require 'pathname'
require Pathname(__FILE__).dirname.expand_path.parent + 'lib/data_mapper/support/kernel'

require __DIR__.parent + 'lib/data_mapper'

OUTPUT = __DIR__.parent + 'profile_results.txt'

SOCKET_FILE = Pathname.glob(%w[
  /opt/local/var/run/mysql5/mysqld.sock
  tmp/mysqld.sock
  tmp/mysql.sock
]).find(&:socket?)

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

require 'ruby-prof'

# RubyProf, making profiling Ruby pretty since 1899!
def profile(&b)
  result  = RubyProf.profile &b
  printer = RubyProf::FlatPrinter.new(result)
  printer.print(OUTPUT.open('w+'))
end

profile do
  10.times do
    Exhibit.all(:limit => 1000)
  end
end

puts "Done!"
