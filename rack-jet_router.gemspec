# -*- coding: utf-8 -*-

Gem::Specification.new do |spec|
  spec.name          = "rack-jet_router"
  spec.version       = "$Release: 1.3.1 $".split()[1]
  spec.author        = "kwatch"
  spec.email         = "kwatch@gmail.com"
  spec.platform      = Gem::Platform::RUBY
  spec.summary       = "Super-fast router class for Rack"
  spec.description   = <<~"END"
    Super-fast router class for Rack application, derived from Keight.rb.

    See #{spec.homepage} for details.
  END
  spec.homepage      = "https://github.com/kwatch/rack-jet_router"
  spec.license       = "MIT"

  spec.files         = Dir[
                         "README.md", "MIT-LICENSE", "CHANGES.md",
                         "#{spec.name}.gemspec",
                         "lib/**/*.rb", "test/**/*.rb",
                         "bench/bench.rb", "bench/Gemfile", "bench/Rakefile.rb",
                       ]
  spec.require_path  = "lib"
  spec.test_files    = Dir["test/**/*_test.rb"]   # or: ["test/run_all.rb"]

  spec.required_ruby_version = ">= 2.4"
  spec.add_development_dependency "oktest"            , "~> 1"
  spec.add_development_dependency "benchmarker"       , "~> 1"
end
