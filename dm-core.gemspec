# -*- encoding: utf-8 -*-
require File.expand_path('../lib/dm-core/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = [ "Dan Kubb" ]
  gem.email         = [ "dan.kubb@gmail.com" ]
  gem.summary       = "An Object/Relational Mapper for Ruby"
  gem.description   = "Faster, Better, Simpler."
  gem.homepage      = "http://datamapper.org"
  gem.date          = "2011-10-11"

  gem.files         = `git ls-files`.split("\n")
  gem.test_files    = `git ls-files -- {spec}/*`.split("\n")
  gem.extra_rdoc_files = %w[LICENSE README.md]

  gem.name          = "dm-core"
  gem.require_paths = [ "lib" ]
  gem.version       = DataMapper::VERSION

  gem.add_runtime_dependency('addressable', '~> 2.2')
  gem.add_runtime_dependency('virtus',      '~> 0.5')

  gem.add_development_dependency('rake',  '~> 0.9.2')
  gem.add_development_dependency('rspec', '~> 1.3.2')
end
