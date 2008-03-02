namespace :sphinx do
  desc "Run indexer"
  task :index do
    cd 'config' do
      system 'indexer --all'
    end
  end

  desc "Rotate idendexes and restart searchd server"
  task :rotate do
    cd 'config' do
      system 'indexer --rotate --all'
    end
  end
  
  desc "Start searchd server"
  task :start do
    if File.exists?('/var/run/searchd.pid')
      puts 'Sphinx searchd server is already started.'
    else
      cd 'config' do
        system 'searchd'
        puts 'Sphinx searchd server started.'
      end
    end
  end
  
  desc "Stop searchd server"
  task :stop do
    unless File.exists?('/var/run/searchd.pid')
      puts 'Sphinx searchd server is not running.'
    else
      pid = File.read('/var/run/searchd.pid').chomp
      system "kill #{pid}"
      puts 'Sphinx searchd server stopped.'
    end
  end
  
  desc "Restart searchd server"
  task :restart => [:stop, :start]
end
