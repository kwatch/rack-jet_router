# -*- coding: utf-8 -*-

require 'rack'              rescue nil  unless $rack == '0'
require 'rack/jet_router'   rescue nil  unless $jet  == '0'
require 'rack/multiplexer'  rescue nil  unless $mpx  == '0'
require 'sinatra/base'      rescue nil  unless $sina == '0'
require 'keight'            rescue nil  unless $k8   == '0'
require 'hanami'            rescue nil  unless $hanami == '0'

flag_rack = flag_sinatra = flag_multiplexer = flag_keight = flag_hanami = false
flag_rack        = defined?(Rack) && $rack != '0'
flag_jetrouter   = defined?(Rack::JetRouter)
flag_multiplex   = defined?(Rack::Multiplexer)
flag_sinatra     = defined?(Sinatra)
flag_keight      = defined?(K8)
flag_hanami      = defined?(Hanami::Router)


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
      get "/api/#{x}"     do "<h1>hello</h1>" end
      get "/api/#{x}/:id" do "<h1>id=#{params['id']}</h1>" end
    end
  end

  sina_app = SinaApp.new

end


if flag_keight

  class K8HelloAction < K8::Action
    mapping '',       :GET=>:do_index
    mapping '/{id}',  :GET=>:do_show
    def do_index        ; "<h1>hello</h1>"; end
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


if flag_hanami

  hanami_index = proc do |env|
    [200, {"Content-Type": "text/html"}, ["<h1>hello</h1>"]]
  end
  hanami_show = proc do |env|
    params = env['router.params']
    [200, {"Content-Type": "text/html"}, ["<h1>id=#{params[:id]}</h1>"]]
  end

  hanami_router = Hanami::Router.new
  hanami_router.namespace '/api' do |api|
    ENTRIES.each do |x|
      api.get    "/#{x}"    , to: hanami_index
      api.get    "/#{x}/:id", to: hanami_show
    end
  end

end


def _chk(tuple)
  tuple[0] == 200  or raise "200 expected but got #{tuple[0]}"
  body = tuple[2].each {|x| break x }
  body == "<h1>hello</h1>" || body == "<h1>id=123</h1>" || body == "<h1>id=789</h1>"  or
    raise "#{body.inspect}: unpexpected body"
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
  puts "** keight          : #{K8::RELEASE rescue '-'}"     if flag_keight
  puts "** hanami          : #{Hanami::VERSION rescue '-'}" if flag_hanami
  puts ""
  puts "** N=#{N}"

  ### empty task
  bm.empty_task do
    newenv("/api")
  end


  ### Rack
  if flag_rack
    target_urlpaths.each do |x|
      rack_app1.call(newenv(x))              # warm up
      bm.task("(Rack plain)  #{x}") do       # no routing
        tuple = rack_app1.call(newenv(x))
      end
      _chk(tuple)
    end
    target_urlpaths.each do |x|
      rack_app4.call(newenv(x))              # warm up
      bm.task("(R::Req+Res)  #{x}") do       # no routing
        tuple = rack_app4.call(newenv(x))
      end
      _chk(tuple)
    end
  end

  ### Rack::JetRouter
  if flag_jetrouter
    target_urlpaths.each do |x|
      jet_router.call(newenv(x))             # warm up
      bm.task("(JetRouter)   #{x}") do
        tuple = jet_router.call(newenv(x))
      end
      _chk(tuple)
    end
  end

  ### Rack::Multiplexer
  if flag_multiplex
    target_urlpaths.each do |x|
      mpx_app.call(newenv(x))                # warm up
      bm.task("(Multiplexer) #{x}") do
        tuple = mpx_app.call(newenv(x))
      end
      _chk(tuple)
    end
  end

  ### Sinatra
  if flag_sinatra
    target_urlpaths.each do |x|
      sina_app.call(newenv(x))               # warm up
      bm.task("(Sinatra)     #{x}") do
        tuple = sina_app.call(newenv(x))
      end
      _chk(tuple)
    end
  end

  ### Keight
  if flag_keight
    target_urlpaths.each do |x|
      k8_app.call(newenv(x))                 # warm up
      bm.task("(Keight.rb)   #{x}") do
        tuple = k8_app.call(newenv(x))
      end
      _chk(tuple)
    end
  end

  if flag_hanami
    target_urlpaths.each do |x|
      hanami_router.call(newenv(x))          # warm up
      bm.task("(Hanami::Router) #{x}") do
        tuple = hanami_router.call(newenv(x))
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
RUBY_PATCHLEVEL:  0
RUBY_PLATFORM:    x86_64-darwin15

** rack            : 1.6.4
** rack-jet_router : 1.1.0
** rack-multiplexer: 0.0.8
** sinatra         : 1.4.6
** keight          : 0.2.0

** N=1000000

##                                     user       sys     total      real
##                                     user       sys     total      real
(Empty)                              6.8300    0.0600    6.8900    6.9270
(Rack plain)  /api/aaa01             1.0400    0.0200    1.0600    1.0619
(Rack plain)  /api/aaa01/123         0.9000   -0.0000    0.9000    0.8729
(Rack plain)  /api/zzz26             0.8400   -0.0100    0.8300    0.7978
(Rack plain)  /api/zzz26/789         0.8400   -0.0200    0.8200    0.7930
(R::Req+Res)  /api/aaa01             9.5600   -0.0000    9.5600    9.5361
(R::Req+Res)  /api/aaa01/123         9.5600   -0.0100    9.5500    9.5321
(R::Req+Res)  /api/zzz26             9.8400   -0.0000    9.8400    9.8096
(R::Req+Res)  /api/zzz26/789         9.6000   -0.0100    9.5900    9.5697
(JetRouter)   /api/aaa01             1.3600   -0.0100    1.3500    1.3231
(JetRouter)   /api/aaa01/123         5.9900    0.0200    6.0100    5.9796
(JetRouter)   /api/zzz26             1.4500   -0.0100    1.4400    1.4089
(JetRouter)   /api/zzz26/789         6.5200    0.0200    6.5400    6.5142
(Multiplexer) /api/aaa01             5.8900    0.0400    5.9300    5.9073
(Multiplexer) /api/aaa01/123        18.1400    0.0800   18.2200   18.2102
(Multiplexer) /api/zzz26            23.7700   -0.0400   23.7300   24.4013
(Multiplexer) /api/zzz26/789        36.1800   -0.0200   36.1600   36.1558
(Sinatra)     /api/aaa01            86.6500   18.0500  104.7000  104.7575
(Sinatra)     /api/aaa01/123        97.0900   18.4900  115.5800  115.8220
(Sinatra)     /api/zzz26           126.9900   18.5100  145.5000  145.5943
(Sinatra)     /api/zzz26/789       136.7700   18.6400  155.4100  155.5191
(Keight.rb)   /api/aaa01             6.4800   -0.0100    6.4700    6.4314
(Keight.rb)   /api/aaa01/123        10.2600    0.0000   10.2600   10.2339
(Keight.rb)   /api/zzz26             6.6200   -0.0100    6.6100    6.5769
(Keight.rb)   /api/zzz26/789        10.8700    0.0100   10.8800   10.8545

## Ranking                             real
(Rack plain)  /api/zzz26/789         0.7930 (100.0%) ********************
(Rack plain)  /api/zzz26             0.7978 ( 99.4%) ********************
(Rack plain)  /api/aaa01/123         0.8729 ( 90.8%) ******************
(Rack plain)  /api/aaa01             1.0619 ( 74.7%) ***************
(JetRouter)   /api/aaa01             1.3231 ( 59.9%) ************
(JetRouter)   /api/zzz26             1.4089 ( 56.3%) ***********
(Multiplexer) /api/aaa01             5.9073 ( 13.4%) ***
(JetRouter)   /api/aaa01/123         5.9796 ( 13.3%) ***
(Keight.rb)   /api/aaa01             6.4314 ( 12.3%) **
(JetRouter)   /api/zzz26/789         6.5142 ( 12.2%) **
(Keight.rb)   /api/zzz26             6.5769 ( 12.1%) **
(R::Req+Res)  /api/aaa01/123         9.5321 (  8.3%) **
(R::Req+Res)  /api/aaa01             9.5361 (  8.3%) **
(R::Req+Res)  /api/zzz26/789         9.5697 (  8.3%) **
(R::Req+Res)  /api/zzz26             9.8096 (  8.1%) **
(Keight.rb)   /api/aaa01/123        10.2339 (  7.7%) **
(Keight.rb)   /api/zzz26/789        10.8545 (  7.3%) *
(Multiplexer) /api/aaa01/123        18.2102 (  4.4%) *
(Multiplexer) /api/zzz26            24.4013 (  3.2%) *
(Multiplexer) /api/zzz26/789        36.1558 (  2.2%)
(Sinatra)     /api/aaa01           104.7575 (  0.8%)
(Sinatra)     /api/aaa01/123       115.8220 (  0.7%)
(Sinatra)     /api/zzz26           145.5943 (  0.5%)
(Sinatra)     /api/zzz26/789       155.5191 (  0.5%)
