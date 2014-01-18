# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "capcloudext/version"

Gem::Specification.new do |s|
  s.name        = "capcloudext"
  s.version     = CapCloudExt::VERSION
  s.authors     = ["Sumit Vij", "Nitin Arora", "Geert Jansen"]
  s.email       = ["sumit@whodini.com", "nitin@whodini.com"]
  s.homepage    = "http://github.com/whodini/capify-cloud-ext"
  s.summary     = %q{Import the server ips, roles, groups from AWS, Ravello cloud providers server tags}


  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]


  s.add_dependency "capistrano", "~> 2.0"
  s.add_dependency "fog"
  s.add_dependency "colored"
end
