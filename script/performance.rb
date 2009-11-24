#!/usr/bin/env ruby -Ku

require 'ftools'
require 'rubygems'

gem 'activerecord', '~> 2.3.4'
gem 'addressable',  '~> 2.1'
gem 'faker',        '~> 0.3.1'
gem 'rbench',       '~> 0.2.3'

require 'active_record'
require 'addressable/uri'
require 'faker'
require 'rbench'

require File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib', 'dm-core'))

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
  :database => 'dm_core_test',
}

configuration_options[:socket] = socket_file unless socket_file.nil?

log_dir = DataMapper.root / 'log'
log_dir.mkdir unless log_dir.directory?

DataMapper::Logger.new(log_dir / 'dm.log', :off)
adapter = DataMapper.setup(:default, "mysql://root@localhost/dm_core_test?socket=#{socket_file}")

if configuration_options[:adapter]
  sqlfile       = File.join(File.dirname(__FILE__), '..', 'tmp', 'performance.sql')
  mysql_bin     = %w[ mysql mysql5 ].select { |bin| `which #{bin}`.length > 0 }
  mysqldump_bin = %w[ mysqldump mysqldump5 ].select { |bin| `which #{bin}`.length > 0 }
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

class User
  include DataMapper::Resource

  property :id,         Serial
  property :name,       String
  property :email,      String
  property :about,      Text,   :lazy => false
  property :created_on, Date
end

class Exhibit
  include DataMapper::Resource

  property :id,         Serial
  property :name,       String
  property :zoo_id,     Integer
  property :user_id,    Integer
  property :notes,      Text,    :lazy => false
  property :created_on, Date

  belongs_to :user
end

DataMapper.auto_migrate!

def touch_attributes(*exhibits)
  exhibits.flatten.each do |exhibit|
    exhibit.id
    exhibit.name
    exhibit.created_on
  end
end

def touch_relationships(*exhibits)
  exhibits.flatten.each do |exhibit|
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
  puts 'Generating data for benchmarking...'

  # pre-compute the insert statements and fake data compilation,
  # so the benchmarks below show the actual runtime for the execute
  # method, minus the setup steps

  # Using the same paragraph for all exhibits because it is very slow
  # to generate unique paragraphs for all exhibits.
  notes = Faker::Lorem.paragraphs.join($/)
  today = Date.today

  puts 'Inserting 10,000 users and exhibits...'
  10_000.times do
    user = User.create(
      :created_on => today,
      :name       => Faker::Name.name,
      :email      => Faker::Internet.email
    )

    Exhibit.create(
      :created_on => today,
      :name       => Faker::Company.name,
      :user       => user,
      :notes      => notes,
      :zoo_id     => rand(10).ceil
    )
  end

  if sqlfile
    answer = nil
    until answer && answer[/\A(?:y(?:es)?|no?)\b/i]
      print('Would you like to dump data into tmp/performance.sql (for faster setup)? [Yn]');
      STDOUT.flush
      answer = gets
    end

    if %w[ y yes ].include?(answer.downcase)
      File.makedirs(File.dirname(sqlfile))
      #adapter.execute("SELECT * INTO OUTFILE '#{sqlfile}' FROM exhibits;")
      `#{mysqldump_bin} -u #{c[:username]} #{"-p#{c[:password]}" unless c[:password].blank?} #{c[:database]} exhibits users > #{sqlfile}`
      puts "File saved\n"
    end
  end
end

TIMES = ENV.key?('x') ? ENV['x'].to_i : 10_000

puts 'You can specify how many times you want to run the benchmarks with rake:perf x=(number)'
puts 'Some tasks will be run 10 and 1000 times less than (number)'
puts "Benchmarks will now run #{TIMES} times"
# Inform about slow benchmark
# answer = nil
# until answer && answer[/^$|y|yes|n|no/]
#   print("A slow benchmark exposing problems with SEL is newly added. It takes approx. 20s\n");
#   print("you have scheduled it to run #{TIMES / 100} times.\nWould you still include the particular benchmark? [Yn]")
#   STDOUT.flush
#   answer = gets
# end
# run_rel_bench = answer[/^$|y|yes/] ? true : false


RBench.run(TIMES) do

  column :times
  column :ar, :title => 'AR 2.3.2'
  column :dm, :title => "DM #{DataMapper::VERSION}"
  column :diff, :compare => [:ar, :dm]

  report 'Model#id', (TIMES * 100).ceil do
    ar_obj = ARExhibit.find(1)
    dm_obj = Exhibit.get(1)

    ar { ar_obj.id }
    dm { dm_obj.id }
  end

  report 'Model.new (instantiation)' do
    ar { ARExhibit.new }
    dm { Exhibit.new }
  end

  report 'Model.new (setting attributes)' do
    attrs = { :name => 'sam', :zoo_id => 1 }
    ar { ARExhibit.new(attrs) }
    dm { Exhibit.new(attrs) }
  end

  report 'Model.get specific (not cached)' do
    ActiveRecord::Base.uncached { ar { touch_attributes(ARExhibit.find(1)) } }
    dm { touch_attributes(Exhibit.get(1)) }
  end

  report 'Model.get specific (cached)' do
    ActiveRecord::Base.cache     { ar { touch_attributes(ARExhibit.find(1)) } }
    Exhibit.repository(:default) { dm { touch_attributes(Exhibit.get(1)) } }
  end

  report 'Model.first' do
    ar { touch_attributes(ARExhibit.first) }
    dm { touch_attributes(Exhibit.first) }
  end

  report 'Model.all limit(100)', (TIMES / 10).ceil do
    ar { touch_attributes(ARExhibit.find(:all, :limit => 100)) }
    dm { touch_attributes(Exhibit.all(:limit => 100)) }
  end

  report 'Model.all limit(100) with relationship', (TIMES / 10).ceil do
    ar { touch_relationships(ARExhibit.all(:limit => 100, :include => [ :user ])) }
    dm { touch_relationships(Exhibit.all(:limit => 100)) }
  end

  report 'Model.all limit(10,000)', (TIMES / 1000).ceil do
    ar { touch_attributes(ARExhibit.find(:all, :limit => 10_000)) }
    dm { touch_attributes(Exhibit.all(:limit => 10_000)) }
  end

  exhibit = {
    :name       => Faker::Company.name,
    :zoo_id     => rand(10).ceil,
    :notes      => Faker::Lorem.paragraphs.join($/),
    :created_on => Date.today
  }

  report 'Model.create' do
    ar { ARExhibit.create(exhibit) }
    dm { Exhibit.create(exhibit) }
  end

  report 'Resource#attributes=' do
    attrs_first  = { :name => 'sam', :zoo_id => 1 }
    attrs_second = { :name => 'tom', :zoo_id => 1 }
    ar { exhibit = ARExhibit.new(attrs_first); exhibit.attributes = attrs_second }
    dm { exhibit = Exhibit.new(attrs_first);   exhibit.attributes = attrs_second }
  end

  report 'Resource#update' do
    ar { ARExhibit.find(1).update_attributes(:name => 'bob') }
    dm { Exhibit.get(1).update(:name => 'bob') }
  end

  report 'Resource#destroy' do
    ar { ARExhibit.first.destroy }
    dm { Exhibit.first.destroy }
  end

  report 'Model.transaction' do
    ar { ARExhibit.transaction { ARExhibit.new } }
    dm { Exhibit.transaction { Exhibit.new } }
  end

  summary 'Total'
end

connection = adapter.send(:open_connection)
command = connection.create_command('DROP TABLE exhibits')
command = connection.create_command('DROP TABLE users')
command.execute_non_query rescue nil
connection.close
