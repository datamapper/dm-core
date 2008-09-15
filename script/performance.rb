#!/usr/bin/env ruby

require File.join(File.dirname(__FILE__), '..', 'lib', 'dm-core')
require File.join(File.dirname(__FILE__), '..', 'lib', 'dm-core', 'version')

require 'rubygems'
require 'ftools'

# sudo gem install rbench
# OR git clone git://github.com/somebee/rbench.git , rake install
gem 'rbench', '>=0.2.2'
require 'rbench'

gem 'faker', '>=0.3.1'
require 'faker'

gem 'activerecord', '>=2.1.0'
require 'active_record'

socket_file = Pathname.glob(%w[
  /opt/local/var/run/mysql5/mysqld.sock
  tmp/mysqld.sock
  /tmp/mysqld.sock
  tmp/mysql.sock
  /tmp/mysql.sock
  /var/mysql/mysql.sock
  /var/run/mysqld/mysqld.sock
]).find { |path| path.socket? }

configuration_options = {
  :adapter => 'mysql',
  :username => 'root',
  :password => '',
  :database => 'data_mapper_1',
}

configuration_options[:socket] = socket_file unless socket_file.nil?

log_dir = DataMapper.root / 'log'
log_dir.mkdir unless log_dir.directory?

DataMapper::Logger.new(log_dir / 'dm.log', :off)
adapter = DataMapper.setup(:default, "mysql://root@localhost/data_mapper_1?socket=#{socket_file}")

if configuration_options[:adapter]
  sqlfile = File.join(File.dirname(__FILE__),'..','tmp','performance.sql')
  mysql_bin = %w[mysql mysql5].select{|bin| `which #{bin}`.length > 0 }
  mysqldump_bin = %w[mysqldump mysqldump5].select{|bin| `which #{bin}`.length > 0 }
end

ActiveRecord::Base.logger = Logger.new(log_dir / 'ar.log')
ActiveRecord::Base.logger.level = 0

ActiveRecord::Base.establish_connection(configuration_options)

class ARExhibit < ActiveRecord::Base #:nodoc:
  set_table_name 'exhibits'
  
  belongs_to :user, :class_name => 'ARUser', :foreign_key => 'user_id'
end

class ARUser < ActiveRecord::Base #:nodoc:
  set_table_name 'users'
  
  has_many :exhibits, :foreign_key => 'user_id'
  
end

ARExhibit.find_by_sql('SELECT 1')

class Exhibit
  include DataMapper::Resource

  property :id,         Serial
  property :name,       String
  property :zoo_id,     Integer
  property :user_id,    Integer
  property :notes,      Text, :lazy => true
  property :created_on, Date
  
  belongs_to :user
#  property :updated_at, DateTime
end

class User
  include DataMapper::Resource
  
  property :id,    Serial
  property :name,  String
  property :email, String
  property :about, Text, :lazy => true
  property :created_on, Date
  
end

touch_attributes = lambda do |exhibits|
  [*exhibits].each do |exhibit|
    exhibit.id
    exhibit.name
    exhibit.created_on
  end
end

touch_relationships = lambda do |exhibits|
  [*exhibits].each do |exhibit|
    exhibit.id
    exhibit.name
    exhibit.created_on
    exhibit.user
  end
end


c = configuration_options

if sqlfile && File.exists?(sqlfile)
  puts "Found data-file. Importing from #{sqlfile}"
  #adapter.execute("LOAD DATA LOCAL INFILE '#{sqlfile}' INTO TABLE exhibits")
  `#{mysql_bin} -u #{c[:username]} #{"-p#{c[:password]}" unless c[:password].blank?} #{c[:database]} < #{sqlfile}`
else
  
  puts "Generating data for benchmarking..."
  
  User.auto_migrate!
  Exhibit.auto_migrate!
  
  users = []
  exhibits = []
  
  # pre-compute the insert statements and fake data compilation,
  # so the benchmarks below show the actual runtime for the execute
  # method, minus the setup steps
  
  # Using the same paragraph for all exhibits because it is very slow
  # to generate unique paragraphs for all exhibits.
  paragraph = Faker::Lorem.paragraphs.join($/)
  
  10_000.times do |i|
    users << [
      'INSERT INTO `users` (`name`,`email`,`created_on`) VALUES (?, ?, ?)',
      Faker::Name.name,
      Faker::Internet.email,
      Date.today
    ]
  
    exhibits << [
      'INSERT INTO `exhibits` (`name`, `zoo_id`, `user_id`, `notes`, `created_on`) VALUES (?, ?, ?, ?, ?)',
      Faker::Company.name,
      rand(10).ceil,
      i,
      paragraph,#Faker::Lorem.paragraphs.join($/),
      Date.today
    ]
  end
  
  puts "Inserting 10,000 users..."  
  10_000.times { |i| adapter.execute(*users.at(i)) }
  puts "Inserting 10,000 exhibits..."  
  10_000.times { |i| adapter.execute(*exhibits.at(i)) }

  if sqlfile
    answer = nil
    until answer && answer[/^$|y|yes|n|no/]
      print("Would you like to dump data into tmp/performance.sql (for faster setup)? [Yn]");
      STDOUT.flush
      answer = gets
    end

    if answer[/^$|y|yes/]
      File.makedirs(File.dirname(sqlfile))
      #adapter.execute("SELECT * INTO OUTFILE '#{sqlfile}' FROM exhibits;")
      `#{mysqldump_bin} -u #{c[:username]} #{"-p#{c[:password]}" unless c[:password].blank?} #{c[:database]} exhibits users > #{sqlfile}`
      puts "File saved\n"
    end
  end

end

TIMES = ENV['x'] ? ENV['x'].to_i : 10_000

puts "You can specify how many times you want to run the benchmarks with rake:perf x=(number)"
puts "Some tasks will be run 10 and 1000 times less than (number)"
puts "Benchmarks will now run #{TIMES} times"
# Inform about slow benchmark
answer = nil
until answer && answer[/^$|y|yes|n|no/]
  print("A slow benchmark exposing problems with SEL is newly added. It takes approx. 20s\n");
  print("you have scheduled it to run #{TIMES / 100} times.\nWould you still include the particular benchmark? [Yn]")
  STDOUT.flush
  answer = gets
end
run_rel_bench = answer[/^$|y|yes/] ? true : false


RBench.run(TIMES) do

  column :times
  column :dm, :title => "DM #{DataMapper::VERSION}"
  column :ar, :title => "AR 2.1"
  column :diff, :compare => [:dm,:ar]

  report "Model.new (instantiation)" do
    dm { Exhibit.new }
    ar { ARExhibit.new }
  end
  
  report "Model.new (setting attributes)" do
    attrs = {:name => 'sam', :zoo_id => 1}
    dm { Exhibit.new(attrs) }
    ar { ARExhibit.new(attrs) }
  end
  
  report "Model.get specific (not cached)" do
    dm { touch_attributes[Exhibit.get(1)] }
    ActiveRecord::Base.uncached { ar { touch_attributes[ARExhibit.find(1)] } }
  end
  
  report "Model.get specific (cached)" do
    Exhibit.repository(:default) { dm { touch_attributes[Exhibit.get(1)]    } }
    ActiveRecord::Base.cache    { ar { touch_attributes[ARExhibit.find(1)] } }
  end
  
  report "Model.first" do
    dm { touch_attributes[Exhibit.first]   }
    ar { touch_attributes[ARExhibit.first] }
  end
  
  report "Model.all limit(100)", (TIMES / 10.0).ceil do
    dm { touch_attributes[Exhibit.all(:limit => 100)] }
    ar { touch_attributes[ARExhibit.find(:all, :limit => 100)] }
  end
  
  report "Model.all limit(10,000)", (TIMES / 1000.0).ceil do
    dm { touch_attributes[Exhibit.all(:limit => 10_000)] }
    ar { touch_attributes[ARExhibit.find(:all, :limit => 10_000)] }
  end
  
  report "Model.all limit(100) with relationship", (TIMES / 100.0).ceil do
    dm { touch_relationships[Exhibit.all(:limit => 1000)] }
    ar { touch_relationships[ARExhibit.all(:limit => 1000, :include => [:user])] }
  end # if run_rel_bench

  create_exhibit = {
    :name       => Faker::Company.name,
    :zoo_id     => rand(10).ceil,
    :notes      => Faker::Lorem.paragraphs.join($/),
    :created_on => Date.today
  }

  report "Model.create" do
    dm { Exhibit.create(create_exhibit)   }
    ar { ARExhibit.create(create_exhibit) }
  end
  
  report "Resource#attributes" do
    attrs_first  = {:name => 'sam', :zoo_id => 1}
    attrs_second = {:name => 'tom', :zoo_id => 1}
    dm { e = Exhibit.new(attrs_first); e.attributes = attrs_second }
    ar { e = ARExhibit.new(attrs_first); e.attributes = attrs_second }
  end
  
  report "Resource#update" do
    dm { e = Exhibit.get(1); e.name = 'bob'; e.save   }
    ar { e = ARExhibit.find(1); e.name = 'bob'; e.save  }
  end
  
  report "Resource#destroy" do
    dm { Exhibit.first.destroy }
    ar { ARExhibit.first.destroy }
  end
  
  report "Model.transaction" do
    dm { Exhibit.transaction do
      Exhibit.new
    end }
    ar { ARExhibit.transaction do
      ARExhibit.new
    end }
  end

  summary "Total"

end

connection = adapter.send(:create_connection)
command = connection.create_command("DROP TABLE exhibits")
command = connection.create_command("DROP TABLE users")
command.execute_non_query rescue nil
connection.close
