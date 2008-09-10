#!/usr/bin/env ruby

require File.join(File.dirname(__FILE__), '..', 'lib', 'dm-core')

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

DataMapper::Logger.new(log_dir / 'dm.log', :debug)
adapter = DataMapper.setup(:default, "mysql://root@localhost/data_mapper_1?socket=#{socket_file}")

if configuration_options[:adapter]
  sqlfile = File.join(File.dirname(__FILE__),'..','tmp','perf.sql')
  mysql_bin = %w[mysql mysql5].select{|bin| `which #{bin}`.length > 0 }
  mysqldump_bin = %w[mysqldump mysqldump5].select{|bin| `which #{bin}`.length > 0 }
end

ActiveRecord::Base.logger = Logger.new(log_dir / 'ar.log')
ActiveRecord::Base.logger.level = 0

ActiveRecord::Base.establish_connection(configuration_options)

class ARExhibit < ActiveRecord::Base #:nodoc:
  set_table_name 'exhibits'
end

ARExhibit.find_by_sql('SELECT 1')

class Exhibit
  include DataMapper::Resource

  property :id,         Serial
  property :name,       String
  property :zoo_id,     Integer
  property :notes,      Text, :lazy => true
  property :created_on, Date
#  property :updated_at, DateTime
end

touch_attributes = lambda do |exhibits|
  [*exhibits].each do |exhibit|
    exhibit.id
    exhibit.name
    exhibit.created_on
#    exhibit.updated_at
  end
end


c = configuration_options

if sqlfile && File.exists?(sqlfile)
  puts "Found data-file. Importing from #{sqlfile}"
  #adapter.execute("LOAD DATA LOCAL INFILE '#{sqlfile}' INTO TABLE exhibits")
  `#{mysql_bin} -u #{c[:username]} #{"-p#{c[:password]}" unless c[:password].blank?} #{c[:database]} < #{sqlfile}`
else

  Exhibit.auto_migrate!

  exhibits = []
  # pre-compute the insert statements and fake data compilation,
  # so the benchmarks below show the actual runtime for the execute
  # method, minus the setup steps
  10_000.times do
    exhibits << [
      'INSERT INTO `exhibits` (`name`, `zoo_id`, `notes`, `created_on`) VALUES (?, ?, ?, ?)',
      Faker::Company.name,
      rand(10).ceil,
      Faker::Lorem.paragraphs.join($/),
      Date.today
    ]
  end
  10_000.times { |i| adapter.execute(*exhibits.at(i)) }

  if sqlfile
    answer = nil
    until answer && answer[/^$|y|yes|n|no/]
      print("Would you like to dump data into tmp/perf.sql (for faster setup)? [Yn]");
      STDOUT.flush
      answer = gets
    end

    if answer[/^$|y|yes/]
      File.makedirs(File.dirname(sqlfile))
      #adapter.execute("SELECT * INTO OUTFILE '#{sqlfile}' FROM exhibits;")
      `#{mysqldump_bin} -u #{c[:username]} #{"-p#{c[:password]}" unless c[:password].blank?} #{c[:database]} exhibits > #{sqlfile}`
      puts "File saved\n"
    end
  end

end

TIMES = ENV['x'] ? ENV['x'].to_i : 10_000

puts "You can specify how many times you want to run the benchmarks with rake:perf x=(number)"
puts "Some tasks will be run 10 and 1000 times less than (number)"
puts "Benchmarks will now run #{TIMES} times"

RBench.run(TIMES) do

  column :times
  column :dm, :title => "DM 0.9.4"
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

  report "Model.all limit(100)", TIMES / 10 do
    dm { touch_attributes[Exhibit.all(:limit => 100)] }
    ar { touch_attributes[ARExhibit.find(:all, :limit => 100)] }
  end

  report "Model.all limit(10,000)", TIMES / 1000 do
    dm { touch_attributes[Exhibit.all(:limit => 10_000)] }
    ar { touch_attributes[ARExhibit.find(:all, :limit => 10_000)] }
  end

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

  report "Resource#update" do
    dm { e = Exhibit.get(1); e.name = 'bob'; e.save   }
    ar { e = ARExhibit.find(1); e.name = 'bob'; e.save  }
  end

  report "Resource#destroy" do
    dm { Exhibit.first.destroy }
    ar { ARExhibit.first.destroy }
  end

  summary "Total"

end

connection = adapter.send(:create_connection)
command = connection.create_command("DROP TABLE exhibits")
command.execute_non_query rescue nil
connection.close
