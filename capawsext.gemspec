# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "capawsext/version"

Gem::Specification.new do |s|
  s.name        = "capawsext"
  s.version     = CapAwsExt::VERSION
  s.authors     = ["Sumit vij"]
  s.email       = ["sumit@whodini.com"]
  s.homepage    = "http://github.com/thedebugger/capawsext"
  s.summary     = %q{Import the server ips, roles, groups from AWS server tags}


  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]


  s.add_dependency "capistrano", "~> 2.0"
  s.add_dependency "fog"
  s.add_dependency "colored"
end
