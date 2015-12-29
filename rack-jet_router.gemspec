# -*- coding: utf-8 -*-

Gem::Specification.new do |spec|
  spec.name          = "rack-jet_router"
  spec.version       = '$Release: 1.1.1 $'.split()[1]
  spec.authors       = ["makoto kuwata"]
  spec.email         = ["kwa(at)kuwata-lab.com"]

  spec.summary       = "Super-fast router class for Rack"
  spec.description   = <<'END'
Super-fast router class for Rack application, derived from Keight.rb.
END
  spec.homepage      = "https://github.com/kwatch/rack-jet_router"
  spec.license       = "MIT-License"

  spec.files         = Dir[*%w[
                         README.md MIT-LICENSE Rakefile rack-jet_router.gemspec
                         lib/**/*.rb
                         test/test_helper.rb test/**/*_test.rb
                       ]]
  spec.require_paths = ["lib"]

  spec.required_ruby_version = '>= 2.0'
  spec.add_development_dependency "bundler"
  spec.add_development_dependency "minitest"
  spec.add_development_dependency "minitest-ok"
end
