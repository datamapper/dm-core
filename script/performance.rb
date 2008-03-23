#!/usr/bin/env ruby

require 'pathname'
require Pathname(__FILE__).dirname.expand_path.parent + 'lib/data_mapper/support/kernel'

require 'benchmark'
require 'active_record'

socket_file = Pathname.glob([ 
  "/opt/local/var/run/mysql5/mysqld.sock",
  "tmp/mysqld.sock",
  "tmp/mysql.sock"
]).find { |path| path.socket? }

configuration_options = {
  :adapter => 'mysql',
  :username => 'root',
  :password => '',
  :database => 'data_mapper_1'
}

configuration_options[:socket] = socket_file unless socket_file.nil?

ActiveRecord::Base.establish_connection(configuration_options)

ActiveRecord::Base.find_by_sql('SELECT 1')

class ARExhibit < ActiveRecord::Base #:nodoc:
  set_table_name 'exhibits'
end

require __DIR__.parent + 'lib/data_mapper'

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

N = (ENV['N'] || 1000).to_i

Benchmark::send(ENV['BM'] || :bmbm, 40) do |x|
  
  x.report('ActiveRecord:id') do
    # Force AR to type-cast a few attributes.
    N.times { e = ARExhibit.find(267); e.id; e.name; e.created_on; e.updated_at; }
  end
    
  x.report('DataMapper:id') do
    N.times { Exhibit.get(267) }
  end
    
end
