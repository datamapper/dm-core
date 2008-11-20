require 'spec/rake/spectask'
require 'spec/rake/verify_rcov'

task :default => 'dm:spec'
task :spec    => 'dm:spec'
task :rcov    => 'dm:rcov'

namespace :spec do
  task :public     => 'dm:spec:public'
  task :semipublic => 'dm:spec:semipublic'
end

namespace :rcov do
  task :public     => 'dm:rcov:public'
  task :semipublic => 'dm:rcov:semipublic'
end

RCov::VerifyTask.new(:verify_rcov => :rcov) do |t|
  t.threshold = 87.4 # Make sure you have rcov 0.7 or higher!
end

# TODO: remove the "dm" namespace
namespace :dm do
  def run_spec(name, files, rcov)
    Spec::Rake::SpecTask.new(name) do |t|
      ENV['ADAPTERS'] ||= 'all'
      t.spec_opts << '--options' << ROOT + 'spec/spec.opts'
      t.spec_files = Pathname.glob(ENV['FILES'] || files.to_s)
      t.rcov = rcov
      t.rcov_opts << '--exclude' << 'spec,environment.rb'
      t.rcov_opts << '--text-summary'
    end
  end

  public_specs     = ROOT + 'spec/public/**/*_spec.rb'
  semipublic_specs = ROOT + 'spec/semipublic/**/*_spec.rb'
  all_specs        = ROOT + 'spec/**/*_spec.rb'

  desc "Run all specifications"
  run_spec('spec', all_specs, false)

  desc "Run all specifications with rcov"
  run_spec('rcov', all_specs, true)

  namespace :spec do
    desc "Run public specifications"
    run_spec('public', public_specs, false)

    desc "Run semipublic specifications"
    run_spec('semipublic', semipublic_specs, false)
  end

  namespace :rcov do
    desc "Run public specifications with rcov"
    run_spec('public', public_specs, true)

    desc "Run semipublic specifications with rcov"
    run_spec('semipublic', semipublic_specs, true)
  end

  desc "Run all comparisons with ActiveRecord"
  task :perf do
    sh ROOT + 'script/performance.rb'
  end

  desc "Profile DataMapper"
  task :profile do
    sh ROOT + 'script/profile.rb'
  end
end
