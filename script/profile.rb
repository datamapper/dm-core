#!/usr/bin/env ruby

require 'pathname'
require Pathname(__FILE__).dirname.expand_path.parent + 'lib/data_mapper/support/kernel'

require __DIR__.parent + 'lib/data_mapper'

socket_file = Pathname.glob([ 
  "/opt/local/var/run/mysql5/mysqld.sock",
  "tmp/mysqld.sock",
  "tmp/mysql.sock"
]).find { |path| path.socket? }

@adapter = DataMapper.setup(:default, "mysql://root@localhost/data_mapper_1?socket=#{socket_file}")

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
  result = RubyProf.profile &b

  printer = RubyProf::GraphHtmlPrinter.new(result)
  Pathname('profile_results.html').open('w+') do |file|
    printer.print(file, 0)
  end
end

profile do
  1000.times do
    Exhibit.all(:limit => 1000)
  end
end

puts "Done!"