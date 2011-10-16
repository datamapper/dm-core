# -*- encoding: utf-8 -*-
require File.expand_path('../lib/dm-core/version', __FILE__)

Gem::Specification.new do |gem|
  gem.name          = "dm-core"
  gem.require_paths = [ "lib" ]
  gem.version       = DataMapper::VERSION

  gem.files            = `git ls-files`.split("\n")
  gem.test_files       = `git ls-files -- {spec}/*`.split("\n")
  gem.extra_rdoc_files = %w[LICENSE README.rdoc]

  gem.add_dependency(%q<addressable>, ["~> 2.3"])
  gem.add_dependency(%q<rake>, ["~> 0.9.2"])
  gem.add_dependency(%q<rspec>, ["~> 1.3.2"])

  gem.add_development_dependency('rake',  '~> 0.9.2')
  gem.add_development_dependency('rspec', '~> 1.3.2')
end
