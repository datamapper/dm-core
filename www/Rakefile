#
#  datamapper.org is built with Webby 0.8.2
#
#  Gem webby-0.8.2
#    directory_watcher (>= 1.1.1)
#    heel (>= 0.6.0)
#    hpricot (>= 0.6)
#    logging (>= 0.7.1)
#    rake (>= 0.8.1)
#    rspec (>= 1.1.3)
#
#  Please do not deploy without proofreading and the
#  approval of a maintainer
#
# $Id$

load 'tasks/setup.rb'

task :default => :rebuild

desc 'deploy the site to the webserver'
task :deploy => [:rebuild, 'deploy:rsync']

# EOF
