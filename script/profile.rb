#!/usr/bin/env ruby

require 'pathname'
require Pathname(__FILE__).dirname.expand_path.parent + 'lib/data_mapper/support/kernel'

require __DIR__.parent + 'lib/data_mapper'

if false
  DataMapper.setup(:default, "mysql://root@localhost/data_mapper_1?socket=/opt/local/var/run/mysql5/mysqld.sock")
else
  DataMapper.setup(:default, "mysql://root@localhost/data_mapper_1")
end

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
    Exhibit.fake_it
  end
end

puts "Done!"