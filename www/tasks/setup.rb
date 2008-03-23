
begin
  require 'webby'
rescue LoadError
  require 'rubygems'
  require 'webby'
end

SITE = Webby.site

SITE.page_defaults = {
  'extension' => 'html',
  'layout'    => 'default'
}

SITE.host       = 'dmweb@blake.wieck.com'
SITE.remote_dir = '/var/www/datamapper.org'
SITE.rsync_args = %w(-av --delete)


# Load the other rake files in the tasks folder
Dir.glob('tasks/*.rake').sort.each {|fn| import fn}

# EOF
