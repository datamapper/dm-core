desc 'Run metric_fu'
task :ci do
  require 'metric_fu'

  Rake::Task['spec'].invoke
  Rake::Task['metrics:all'].invoke
end
