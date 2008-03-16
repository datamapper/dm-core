require 'pp'

ENV['LOG_NAME'] = 'spec'
require File.join(File.dirname(__FILE__), '..', 'environment')

# Define a fixtures helper method to load up our test data.
def fixtures(name)
  entry = YAML::load_file(FIle.join(File.dirname(__FILE__), 'fixtures', "#{name}.yaml"))
  klass = begin
    Kernel::const_get(Inflector.classify(Inflector.singularize(name)))
  rescue
    nil
  end

  unless klass.nil?
    repository.logger.debug { "AUTOMIGRATE: #{klass}" }
    klass.auto_migrate!

    (entry.kind_of?(Array) ? entry : [entry]).each do |hash|
      if hash['type']
        Object::const_get(hash['type'])::create(hash)
      else
        klass::create(hash)
      end
    end
  else
    table = repository.table(name.to_s)
    table.create! true
    table.activate_associations!

    #pp repository.schema

    (entry.kind_of?(Array) ? entry : [entry]).each do |hash|
      table.insert(hash)
    end
  end
end

def load_database
  Dir[File.join(File.dirname(__FILE__), 'fixtures' , '*.yaml')].each do |path|
    fixtures(File::basename(path).sub(/\.yaml$/, ''))
  end
end

load_database
