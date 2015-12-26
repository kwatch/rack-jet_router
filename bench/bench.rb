# -*- coding: utf-8 -*-

require 'rack'              rescue nil  unless $rack == '0'
require 'rack/jet_router'   rescue nil  unless $jet  == '0'
require 'rack/multiplexer'  rescue nil  unless $mpx  == '0'
require 'sinatra/base'      rescue nil  unless $sina == '0'
require 'keight'            rescue nil  unless $k8   == '0'

flag_rack = flag_sinatra = flag_multiplexer = flag_keight = false
flag_rack        = defined?(Rack) && $rack != '0'
flag_jetrouter   = defined?(Rack::JetRouter)
flag_multiplex   = defined?(Rack::Multiplexer)
flag_sinatra     = defined?(Sinatra)
flag_keight      = defined?(K8)


ENTRIES = ('a'..'z').map.with_index {|x, i| "%s%02d" % [x*3, i+1] }


if flag_rack

  class RackApp1
    def call(env)
      [200, {"Content-Type"=>"text/html"}, ["<h1>hello</h1>"]]
    end
  end

  class RackApp4
    def call(env)
      req  = Rack::Request.new(env)
      resp = Rack::Response.new
      #[resp.status, resp.headers, ["<h1>hello</h1>"]]
      #[200, {"Content-Type"=>"text/html"}, ["<h1>hello</h1>"]]
      resp.status = 200
      resp.headers["Content-Type"] = "text/html"
      resp.write("<h1>hello</h1>")
      resp.finish()
    end
  end

  rack_app1 = RackApp1.new
  rack_app4 = RackApp4.new

end


if flag_jetrouter

  class JetHelloApp1
    def call(env)
      [200, {"Content-Type"=>"text/html"}, ["<h1>hello</h1>"]]
    end
  end

  class JetHelloApp2
    def call(env)
      d = env['rack.urlpath_params']
      [200, {"Content-Type"=>"text/html"}, ["<h1>id=#{d['id']}</h1>"]]
    end
  end

  jet_router = proc {
    mapping = [
      ['/api', ENTRIES.map {|x|
                 ["/#{x}", [
                   ['',        JetHelloApp1.new],
                   ['/:id',    JetHelloApp2.new],
                 ]]
               },
      ],
    ]
    opts = {
      urlpath_cache_size:           ($k8cache || 0).to_i,
      enable_urlpath_param_range:   $k8range != '0',
    }
    Rack::JetRouter.new(mapping, opts)
  }.call()

end


if flag_multiplex

  class MpxHelloApp1
    def call(env)
      [200, {"Content-Type"=>"text/html"}, ["<h1>hello</h1>"]]
    end
  end

  class MpxHelloApp2
    def call(env)
      d = env['rack.request.query_hash']
      [200, {"Content-Type"=>"text/html"}, ["<h1>id=#{d['id']}</h1>"]]
    end
  end

  mpx_app = Rack::Multiplexer.new()
  ENTRIES.each do |x|
    mpx_app.get "/api/#{x}"     , MpxHelloApp1.new
    mpx_app.get "/api/#{x}/:id" , MpxHelloApp2.new
  end

end


if flag_sinatra

  class SinaApp < Sinatra::Base
    set :sessions   , false
    set :logging    , false
    set :protection , false
    set :x_cascade  , false
    #
    ENTRIES.each do |x|
      get "/api/#{x}"     do "<h1>index</h1>" end
      get "/api/#{x}/:id" do "<h1>id=#{params['id']}</h1>" end
    end
  end

  sina_app = SinaApp.new

end


if flag_keight

  class K8HelloAction < K8::Action
    mapping '',       :GET=>:do_index
    mapping '/{id}',  :GET=>:do_show
    def do_index        ; "<h1>index</h1>"; end
    def do_show(id)     ; "<h1>id=#{id.inspect}</h1>"; end
  end

  k8_app = K8::RackApplication.new([
      ['/api', ENTRIES.map {|x|
                 ["/#{x}",  K8HelloAction]
               }
      ],
  ], urlpath_cache_size: 0)

  #k8_app.find('/api/books')     # warm up

end


def _chk(tuple)
  tuple[0] == 200  or raise "200 expected but got #{tuple[0]}"
  GC.start
end

$environ = Rack::MockRequest.env_for("http://localhost/", method: 'GET')
$environ.freeze

def newenv(path)
  env = $environ.dup
  env['PATH_INFO'] = path
  env
end


require './benchmarker'

N = ($N || 100000).to_i
Benchmarker.new(:width=>33, :loop=>N) do |bm|

  #flag_sinatra   = false   # because too slow
  target_urlpaths = [
    "/api/aaa01",
    "/api/aaa01/123",
    "/api/zzz26",
    "/api/zzz26/789",
  ]
  tuple = nil

  puts ""
  puts "** rack            : #{Rack.release}"               if flag_rack
  puts "** rack-jet_router : #{Rack::JetRouter::RELEASE rescue '-'}"   if flag_jetrouter
  puts "** rack-multiplexer: #{Rack::Multiplexer::VERSION}" if flag_multiplex
  puts "** sinatra         : #{Sinatra::VERSION}"           if flag_sinatra
  puts "** keight          : #{K8::RELEASE rescue '-'}"  if flag_keight
  puts ""
  puts "** N=#{N}"

  ### empty task
  bm.empty_task do
    newenv("/api")
  end


  ### Rack
  if flag_rack
    target_urlpaths.each do |x|
      bm.task("(Rack plain)  #{x}") do       # no routing
        tuple = rack_app1.call(newenv(x))
      end
      _chk(tuple)
    end
    target_urlpaths.each do |x|
      bm.task("(R::Req+Res)  #{x}") do       # no routing
        tuple = rack_app4.call(newenv(x))
      end
      _chk(tuple)
    end
  end

  ### Rack::JetRouter
  if flag_jetrouter
    target_urlpaths.each do |x|
      bm.task("(JetRouter)   #{x}") do
        tuple = jet_router.call(newenv(x))
      end
      _chk(tuple)
    end
  end

  ### Rack::Multiplexer
  if flag_multiplex
    target_urlpaths.each do |x|
      bm.task("(Multiplexer) #{x}") do
        tuple = mpx_app.call(newenv(x))
      end
      _chk(tuple)
    end
  end

  ### Sinatra
  if flag_sinatra
    target_urlpaths.each do |x|
      bm.task("(Sinatra)     #{x}") do
        tuple = sina_app.call(newenv(x))
      end
      _chk(tuple)
    end
  end

  ### Keight
  if flag_keight
    target_urlpaths.each do |x|
      bm.task("(Keight.rb)   #{x}") do
        tuple = k8_app.call(newenv(x))
      end
      _chk(tuple)
    end
  end

end


__END__

###
### Example result
###

$ ruby -I../lib  bench.rb
benchmarker.rb:   release 1.0.0
RUBY_VERSION:     2.3.0
RUBY_PATCHLEVEL:  -1
RUBY_PLATFORM:    x86_64-darwin14

##                                     user       sys     total      real
(Empty)                              0.6900    0.0100    0.7000    0.6986
(Rack plain)  /api/hello             0.1500   -0.0000    0.1500    0.1555
(R::Req+Res)  /api/hello             0.9800    0.0000    0.9800    0.9837
(JetRouter)   /api/hello             0.1600   -0.0100    0.1500    0.1597
(JetRouter)   /api/hello/123         0.6400   -0.0000    0.6400    0.6424
(Multiplexer) /api/hello             0.5100   -0.0000    0.5100    0.5097
(Multiplexer) /api/hello/123         1.7300    0.0000    1.7300    1.7334
(Sinatra)     /api/hello             8.8500    1.8400   10.6900   10.6965
(Sinatra)     /api/hello/123         9.8000    1.8600   11.6600   11.6672
(Keight.rb)   /api/hello             0.7000    0.0000    0.7000    0.6931
(Keight.rb)   /api/hello/123         1.1000   -0.0000    1.1000    1.0954

## Ranking                             real
(Rack plain)  /api/hello             0.1555 (100.0%) ********************
(JetRouter)   /api/hello             0.1597 ( 97.4%) *******************
(Multiplexer) /api/hello             0.5097 ( 30.5%) ******
(JetRouter)   /api/hello/123         0.6424 ( 24.2%) *****
(Keight.rb)   /api/hello             0.6931 ( 22.4%) ****
(R::Req+Res)  /api/hello             0.9837 ( 15.8%) ***
(Keight.rb)   /api/hello/123         1.0954 ( 14.2%) ***
(Multiplexer) /api/hello/123         1.7334 (  9.0%) **
(Sinatra)     /api/hello            10.6965 (  1.5%)
(Sinatra)     /api/hello/123        11.6672 (  1.3%)

## Matrix                              real     [01]     [02]     [03]     [04]     [05]     [06]     [07]     [08]     [09]     [10]
[01] (Rack plain)  /api/hello        0.1555   100.0%   102.7%   327.8%   413.1%   445.7%   632.6%   704.5%  1114.7%  6878.8%  7503.0%
[02] (JetRouter)   /api/hello        0.1597    97.4%   100.0%   319.3%   402.4%   434.1%   616.2%   686.1%  1085.8%  6699.9%  7307.9%
[03] (Multiplexer) /api/hello        0.5097    30.5%    31.3%   100.0%   126.0%   136.0%   193.0%   214.9%   340.1%  2098.4%  2288.8%
[04] (JetRouter)   /api/hello/123    0.6424    24.2%    24.9%    79.3%   100.0%   107.9%   153.1%   170.5%   269.8%  1665.0%  1816.1%
[05] (Keight.rb)   /api/hello        0.6931    22.4%    23.0%    73.5%    92.7%   100.0%   141.9%   158.1%   250.1%  1543.3%  1683.4%
[06] (R::Req+Res)  /api/hello        0.9837    15.8%    16.2%    51.8%    65.3%    70.5%   100.0%   111.4%   176.2%  1087.4%  1186.0%
[07] (Keight.rb)   /api/hello/123    1.0954    14.2%    14.6%    46.5%    58.6%    63.3%    89.8%   100.0%   158.2%   976.5%  1065.1%
[08] (Multiplexer) /api/hello/123    1.7334     9.0%     9.2%    29.4%    37.1%    40.0%    56.7%    63.2%   100.0%   617.1%   673.1%
[09] (Sinatra)     /api/hello       10.6965     1.5%     1.5%     4.8%     6.0%     6.5%     9.2%    10.2%    16.2%   100.0%   109.1%
[10] (Sinatra)     /api/hello/123   11.6672     1.3%     1.4%     4.4%     5.5%     5.9%     8.4%     9.4%    14.9%    91.7%   100.0%
