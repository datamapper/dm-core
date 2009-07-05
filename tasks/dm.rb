require 'spec/rake/spectask'
require 'spec/rake/verify_rcov'

task :default => 'spec'

RCov::VerifyTask.new(:verify_rcov => :rcov) do |config|
  config.threshold = 88.1  # Make sure you have rcov 0.7 or higher!
end

def run_spec(name, files, rcov)
  Spec::Rake::SpecTask.new(name) do |config|
    config.spec_opts << '--options' << ROOT + 'spec/spec.opts'
    config.spec_files = Pathname.glob(ENV['FILES'] || files.to_s).map { |file| file.to_s }
    config.rcov = rcov
    config.rcov_opts << '--exclude' << 'spec'
    config.rcov_opts << '--text-summary'
    config.rcov_opts << '--sort' << 'coverage'
    config.rcov_opts << '--only-uncovered'
    config.rcov_opts << '--profile'
    #config.rcov_opts << '-w'  # TODO: make sure it runs with warnings enabled
  end
end

public_specs     = ROOT + 'spec/public/**/*_spec.rb'
semipublic_specs = ROOT + 'spec/semipublic/**/*_spec.rb'
all_specs        = ROOT + 'spec/**/*_spec.rb'

desc 'Run all specifications'
run_spec('spec', all_specs, false)

desc 'Run all specifications with rcov'
run_spec('rcov', all_specs, true)

namespace :spec do
  desc 'Run public specifications'
  run_spec('public', public_specs, false)

  desc 'Run semipublic specifications'
  run_spec('semipublic', semipublic_specs, false)
end

namespace :rcov do
  desc 'Run public specifications with rcov'
  run_spec('public', public_specs, true)

  desc 'Run semipublic specifications with rcov'
  run_spec('semipublic', semipublic_specs, true)
end

desc 'Run all comparisons with ActiveRecord'
task :perf do
  sh ROOT + 'script/performance.rb'
end

desc 'Profile DataMapper'
task :profile do
  sh ROOT + 'script/profile.rb'
end
