# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'resque/plugins/clues/version'

Gem::Specification.new do |gem|
  gem.name          = "resque-clues"
  gem.version       = Resque::Clues::VERSION
  gem.authors       = ["Lance Woodson"]
  gem.email         = ["lance.woodson@peopleadmin.com"]
  gem.description   = %q{Adds event publishing and job tracking ability to Resque}
  gem.summary       = %q{Adds event publishing and job tracking}
  gem.homepage      = "https://github.com/PeopleAdmin/resque-clues"

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]
  gem.add_dependency 'resque', '>= 1.20.0'
  gem.add_dependency 'multi_json', '~> 1.7.4'
  gem.add_development_dependency 'rake', '~> 0.9.2.2'
  gem.add_development_dependency 'rspec'
  gem.add_development_dependency 'pry'
  gem.add_development_dependency 'pry-debugger'
  gem.add_development_dependency 'cane'
end
