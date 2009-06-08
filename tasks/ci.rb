desc 'Run metric_fu'
task :ci do
  # sudo gem install jscruggs-metric_fu -s http://gems.github.com
  require 'metric_fu'

  Rake::Task['metrics:all'].invoke
end
