# -*- coding: utf-8 -*-

require 'benchmarker'

require 'rack'              rescue nil  unless $rack == '0'
require 'rack/jet_router'   rescue nil  unless $jet  == '0'
require 'rack/multiplexer'  rescue nil  unless $mpx  == '0'
require 'sinatra/base'      rescue nil  unless $sina == '0'
require 'keight'            rescue nil  unless $k8   == '0'
require 'hanami/router'     rescue nil  unless $hanami == '0'

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

  class K8CommentAction < K8::Action
    mapping '/{comment_id}',  :GET=>:do_show
    def do_show(id, comment_id); "<h1>id=#{id}, comment_id=#{comment_id}</h1>"; end
  end

  k8_app = (proc {
    mapping = [
      ["/api", ENTRIES.each_with_object([]) {|x, arr|
                 arr << ["/#{x}"              ,  K8HelloAction]
                 arr << ["/#{x}/{id}/comments",  K8CommentAction]
               }
      ],
    ]
    opts = {
      #urlpath_cache_size: 0,
    }
    K8::RackApplication.new(mapping, **opts)
  }).call()

  #k8_app.find('/api/books')     # warm up

end


if flag_hanami

  ## ref: https://github.com/hanami/router
  hanami_app = Hanami::Router.new do
    index_handler = proc do |env|
      [200, {"Content-Type": "text/html"}, ["<h1>hello</h1>"]]
    end
    show_handler = proc do |env|
      d = env['router.params']
      [200, {"Content-Type": "text/html"}, ["<h1>id=#{d[:id]}</h1>"]]
    end
    comment_handler = proc do |env|
      d = env['router.params']
      [200, {"Content-Type": "text/html"}, ["<h1>id=#{d[:id]}, comment_id=#{d[:comment_id]}</h1>"]]
    end
    #
    scope "api" do
      ENTRIES.each do |x|
        get "/#{x}"    , to: index_handler
        get "/#{x}/:id", to: show_handler
        get "/#{x}/:id/comments/:comment_id", to: comment_handler
      end
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


N = ($N || 100000).to_i
title = "Router library benchmark"
Benchmarker.scope(title, width: 33, loop: 1, iter: 1, extra: 0, sleep: 0) do

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
  puts "** hanami          : #{Hanami::Router::VERSION rescue '-'}" if flag_hanami
  puts ""
  puts "** N=#{N}"

  ### empty task
  task nil do
    i = 0; n = N
    while (i += 1) <= n
      newenv("/api")
    end
  end


  ### Rack
  if flag_rack
    target_urlpaths.each do |x|
      rack_app1.call(newenv(x))              # warm up
      task "(Rack plain)  #{x}" do           # no routing
        i = 0; n = N
        while (i += 1) <= n
          tuple = rack_app1.call(newenv(x))
        end
        tuple
      end
    end
    target_urlpaths.each do |x|
      rack_app4.call(newenv(x))              # warm up
      task "(R::Req+Res)  #{x}" do           # no routing
        i = 0; n = N
        while (i += 1) <= n
          tuple = rack_app4.call(newenv(x))
        end
        tuple
      end
    end
  end

  ### Rack::JetRouter
  if flag_jetrouter
    target_urlpaths.each do |x|
      jet_router.call(newenv(x))             # warm up
      task "(JetRouter)   #{x}" do
        i = 0; n = N
        while (i += 1) <= n
          tuple = jet_router.call(newenv(x))
        end
        tuple
      end
    end
  end

  ### Rack::Multiplexer
  if flag_multiplex
    target_urlpaths.each do |x|
      mpx_app.call(newenv(x))                # warm up
      task "(Multiplexer) #{x}" do
        i = 0; n = N
        while (i += 1) <= n
          tuple = mpx_app.call(newenv(x))
        end
        tuple
      end
    end
  end

  ### Sinatra
  if flag_sinatra
    target_urlpaths.each do |x|
      sina_app.call(newenv(x))               # warm up
      task "(Sinatra)     #{x}" do
        i = 0; n = N
        while (i += 1) <= n
          tuple = sina_app.call(newenv(x))
        end
        tuple
      end
    end
  end

  ### Keight
  if flag_keight
    target_urlpaths.each do |x|
      k8_app.call(newenv(x))                 # warm up
      task "(Keight.rb)   #{x}" do
        i = 0; n = N
        while (i += 1) <= n
          tuple = k8_app.call(newenv(x))
        end
        tuple
      end
    end
  end

  if flag_hanami
    target_urlpaths.each do |x|
      hanami_app.call(newenv(x))          # warm up
      task "(Hanami::Router) #{x}" do
        i = 0; n = N
        while (i += 1) <= n
          tuple = hanami_app.call(newenv(x))
        end
        tuple
      end
    end
  end

  ## validation
  validate do |val|   # or: validate do |val, task_name, tag|
    tuple = val
    assert tuple[0] == 200, "200 expected but got #{tuple[0]}"
    body = tuple[2].each {|x| break x }
    assert body == "<h1>hello</h1>" || body == "<h1>id=123</h1>" || body == "<h1>id=789</h1>", "#{body.inspect}: unpexpected body"
  end

end
