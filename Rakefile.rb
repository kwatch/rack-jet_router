# -*- coding: utf-8 -*-


PROJECT   = "rack-jet_router"
RELEASE   = ENV['RELEASE'] || "0.0.0"
COPYRIGHT = "copyright(c) 2015 kwatch@gmail.com"
LICENSE   = "MIT License"

## Ruby 2.3 doesn't have 'Regexp#match?()' method.
RUBY_VERSIONS = ["3.2", "3.1", "3.0", "2.7", "2.6", "2.5", "2.4"]

Dir.glob('./task/*-task.rb').sort.each {|x| require x }
