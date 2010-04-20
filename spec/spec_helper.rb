require 'pathname'
require 'rubygems'

require 'addressable/uri'
require 'spec'

SPEC_ROOT = Pathname(__FILE__).dirname.expand_path
LIB_ROOT  = SPEC_ROOT.parent + 'lib'

$LOAD_PATH.unshift(LIB_ROOT)

require 'dm-core'

plugins = ENV['PLUGINS'] || ENV['PLUGIN']
plugins = (plugins.to_s.gsub(',',' ').split(' ') + ['dm-migrations']).uniq
plugins.each { |plugin| require plugin }

Pathname.glob((LIB_ROOT  + 'dm-core/spec/**/*.rb'  ).to_s).each { |file| require file }
Pathname.glob((SPEC_ROOT + '{lib,*/shared}/**/*.rb').to_s).each { |file| require file }

ENV['ADAPTERS'] ||= 'all'

# create sqlite3_fs directory if it doesn't exist
temp_db_dir = SPEC_ROOT.join('db')
temp_db_dir.mkpath

DataMapper::Spec::AdapterHelpers.temp_db_dir = temp_db_dir

adapters  = ENV['ADAPTERS'].split(' ').map { |adapter_name| adapter_name.strip.downcase }.uniq
adapters  = DataMapper::Spec::AdapterHelpers.primary_adapters.keys if adapters.include?('all')

DataMapper::Spec::AdapterHelpers.setup_adapters(adapters)

logger = DataMapper::Logger.new(DataMapper.root / 'log' / 'dm.log', :debug)
logger.auto_flush = true

Spec::Runner.configure do |config|

  config.extend(DataMapper::Spec::AdapterHelpers)
  config.include(DataMapper::Spec::PendingHelpers)

  def reset_raise_on_save_failure(object)
    object.instance_eval do
      if defined?(@raise_on_save_failure)
        remove_instance_variable(:@raise_on_save_failure)
      end
    end
  end

  config.after :all do
    DataMapper::Spec.cleanup_models
  end

  config.after :all do
    # global ivar cleanup
    DataMapper::Spec.remove_ivars(self, instance_variables.reject { |ivar| ivar[0, 2] == '@_' })
  end

  config.after :all do
    # WTF: rspec holds a reference to the last match for some reason.
    # When the object ivars are explicitly removed, this causes weird
    # problems when rspec uses it (!).  Why rspec does this I have no
    # idea because I cannot determine the intention from the code.
    DataMapper::Spec.remove_ivars(Spec::Matchers.last_matcher, %w[ @expected ])
  end

end

# remove the Resource#send method to ensure specs/internals do no rely on it
module RemoveSend
  def self.included(model)
    model.send(:undef_method, :send)
    model.send(:undef_method, :freeze)
  end

  DataMapper::Model.append_inclusions self
end
