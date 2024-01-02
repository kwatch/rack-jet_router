# -*- coding: utf-8 -*-
# frozen_string_literal: true


desc "run 'bench.rb' script"
task :bench, :N do |t, args|
  n = args[:N] || 1000000
  ruby "bench.rb", "-n", n
  #ruby "bench.rb", "-n", n, "--sinatra=0", "--multiplexer=0"
  #ruby "bench.rb", "-n", n, "--rack=0", "--jetrouter=0", "--keight=0", "--multiplexer=0", "--sinatra=0", "--hanami=0"
end
