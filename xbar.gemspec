# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "xbar/version"

Gem::Specification.new do |s|
  s.name        = "xbar"
  s.version     = Xbar::VERSION
  s.authors     = ["Michael Schmitz"]
  s.email       = ["lydianblues@gmail.com"]
  s.homepage    = ""
  s.summary     = %q{Dymanic connection router}
  s.description = %q{Manage connection pools to implement shards and mirrors}

  s.rubyforge_project = "xbar"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_development_dependency "rspec"
  s.add_runtime_dependency "mysql2"
end
