require 'pathname'
require 'rubygems'
require 'spec'
require 'dm-core/spec/setup'

ENV['ADAPTER'] ||= 'in_memory'

SPEC_ROOT = Pathname(__FILE__).dirname.expand_path
LIB_ROOT  = SPEC_ROOT.parent + 'lib'

Pathname.glob((LIB_ROOT  + 'dm-core/spec/**/*.rb'          ).to_s).each { |file| require file }
Pathname.glob((SPEC_ROOT + '{lib,support,*/shared}/**/*.rb').to_s).each { |file| require file }

Spec::Runner.configure do |config|

  config.extend( DataMapper::Spec::Adapters::Helpers)
  config.include(DataMapper::Spec::PendingHelpers)
  config.include(DataMapper::Spec::Helpers)

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
