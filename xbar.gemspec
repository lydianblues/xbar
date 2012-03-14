# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "xbar/version"

Gem::Specification.new do |s|
  s.name        = "xbar"
  s.version     = XBar::VERSION
  s.authors     = ["Michael Schmitz"]
  s.email       = ["lydianblues@gmail.com"]
  s.homepage    = ""
  s.summary     = %q{Dymanic connection pool manager for ActiveRecord}
  s.description = %q{Supports MongoDB style sharding and mirroring}

  s.rubyforge_project = "xbar"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_development_dependency "rspec"
  s.add_runtime_dependency "mysql2"
  s.add_dependency 'activerecord'
  s.add_development_dependency 'rake'
  s.add_development_dependency 'actionpack'
  s.add_development_dependency 'appraisal'
  s.add_development_dependency 'rspec', '2.8.0'
  s.add_development_dependency 'mysql2'
  s.add_development_dependency 'pg'
  s.add_development_dependency 'sqlite3'
  s.add_development_dependency 'syntax'
  s.add_development_dependency 'ruby-debug19'
  s.add_development_dependency 'repctl'
#  s.add_development_dependency 'metric_fu'
end
