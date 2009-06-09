desc 'Run metric_fu'
task :ci do
  # sudo gem install jscruggs-metric_fu -s http://gems.github.com
  require 'metric_fu'

  MetricFu::Configuration.run do |config|
    specs = Pathname.glob(ENV['FILES'] || (ROOT + 'spec/**/*_spec.rb').to_s).sort.map { |file| file.to_s }

    config.rcov = {
      :test_files => specs,
      :rcov_opts  => [
        '--sort coverage',
        '--no-html',
        '--text-coverage',
        '--no-color',
        '--profile',
        '--exclude spec',
        "`which spec` -- #{specs.join(' ')}",
      ],
    }
  end

  Rake::Task['metrics:all'].invoke
end
