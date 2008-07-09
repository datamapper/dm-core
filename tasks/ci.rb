task 'ci:doc' => :doc

namespace :ci do

  task :prepare do
    rm_rf ROOT + "ci"
    mkdir_p ROOT + "ci"
    mkdir_p ROOT + "ci/doc"
    mkdir_p ROOT + "ci/cyclomatic"
    mkdir_p ROOT + "ci/token"
  end

  Spec::Rake::SpecTask.new("spec:unit" => :prepare) do |t|
    t.spec_opts = ["--format", "specdoc", "--format", "html:#{ROOT}/ci/unit_rspec_report.html", "--diff"]
    t.spec_files = Pathname.glob(ROOT + "spec/unit/**/*_spec.rb")
    unless ENV['NO_RCOV']
      t.rcov = true
      t.rcov_opts << '--exclude' << "spec,gems"
      t.rcov_opts << '--text-summary'
      t.rcov_opts << '--sort' << 'coverage' << '--sort-reverse'
      t.rcov_opts << '--only-uncovered'
    end
  end

  Spec::Rake::SpecTask.new("spec:integration" => :prepare) do |t|
    t.spec_opts = ["--format", "specdoc", "--format", "html:#{ROOT}/ci/integration_rspec_report.html", "--diff"]
    t.spec_files = Pathname.glob(ROOT + "spec/integration/**/*_spec.rb")
    unless ENV['NO_RCOV']
      t.rcov = true
      t.rcov_opts << '--exclude' << "spec,gems"
      t.rcov_opts << '--text-summary'
      t.rcov_opts << '--sort' << 'coverage' << '--sort-reverse'
      t.rcov_opts << '--only-uncovered'
    end
  end

  task :spec do
    Rake::Task["ci:spec:unit"].invoke
    mv ROOT + "coverage", ROOT + "ci/unit_coverage"

    Rake::Task["ci:spec:integration"].invoke
    mv ROOT + "coverage", ROOT + "ci/integration_coverage"
  end

  task :saikuro => :prepare do
    system "saikuro -c -i lib -y 0 -w 10 -e 15 -o ci/cyclomatic"
    mv 'ci/cyclomatic/index_cyclo.html', 'ci/cyclomatic/index.html'

    system "saikuro -t -i lib -y 0 -w 20 -e 30 -o ci/token"
    mv 'ci/token/index_token.html', 'ci/token/index.html'
  end

  task :publish do
    out = ENV['CC_BUILD_ARTIFACTS'] || "out"
    mkdir_p out unless File.directory? out

    mv "ci/unit_rspec_report.html", "#{out}/unit_rspec_report.html"
    mv "ci/unit_coverage", "#{out}/unit_coverage"
    mv "ci/integration_rspec_report.html", "#{out}/integration_rspec_report.html"
    mv "ci/integration_coverage", "#{out}/integration_coverage"
    mv "ci/doc", "#{out}/doc"
    mv "ci/cyclomatic", "#{out}/cyclomatic_complexity"
    mv "ci/token", "#{out}/token_complexity"
  end
end

#task :ci => %w[ ci:spec ci:doc ci:saikuro install ci:publish ]  # yard-related tasks do not work yet
task :ci => %w[ ci:spec ci:saikuro install ]
