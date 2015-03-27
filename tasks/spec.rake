spec_defaults = lambda do |spec|
  spec.pattern    = 'spec/**/*_spec.rb'
  spec.libs      << 'lib' << 'spec'
  spec.spec_opts << '--loadby random'
  spec.spec_opts << '-c' if RUBY_VERSION < '2.2'
end

begin
  require 'spec/rake/spectask'

  Spec::Rake::SpecTask.new(:spec, &spec_defaults)
rescue LoadError
  task :spec do
    abort 'rspec is not available. In order to run spec, you must: gem install rspec'
  end
end

task :default => :spec
