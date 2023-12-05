# -*- coding: utf-8 -*-

$LOAD_PATH << File.absolute_path("../../lib", __FILE__)

require 'benchmarker'
Benchmarker.parse_cmdopts()

require 'rack'              rescue nil  unless '0' == $opt_rack
require 'rack/jet_router'   rescue nil  unless '0' == $opt_jetrouter
require 'rack/multiplexer'  rescue nil  unless '0' == $opt_multiplexer
require 'sinatra/base'      rescue nil  unless '0' == $opt_sinatra
require 'keight'            rescue nil  unless '0' == $opt_keight
require 'hanami/router'     rescue nil  unless '0' == $opt_hanami

flag_rack        = defined?(Rack) && $opt_rack != '0'
flag_jetrouter   = defined?(Rack::JetRouter)
flag_multiplexer = defined?(Rack::Multiplexer)
flag_sinatra     = defined?(Sinatra)
flag_keight      = defined?(K8)
flag_hanami      = defined?(Hanami::Router)

puts "** rack            : #{!flag_rack      ? '-' : Rack.release}"
puts "** rack-jet_router : #{!flag_jetrouter ? '-' : Rack::JetRouter::RELEASE}"
puts "** rack-multiplexer: #{!flag_multiplexer ? '-' : Rack::Multiplexer::VERSION}"
puts "** sinatra         : #{!flag_sinatra   ? '-' : Sinatra::VERSION}"
puts "** keight          : #{!flag_keight    ? '-' : K8::RELEASE}"
puts "** hanami-router   : #{!flag_hanami    ? '-' : Hanami::Router::VERSION}"


ENTRIES = ('a'..'z').map.with_index {|x, i| "%s%02d" % [x*3, i+1] }

#flag_sinatra   = false   # because too slow
target_urlpaths = [
  "/api/aaa01",
  "/api/aaa01/123",
#  "/api/aaa01/123/comments/7",
  "/api/zzz26",
  "/api/zzz26/456",
#  "/api/zzz26/456/comments/7",
]


if flag_rack

  rack_app1 = proc do |env|
    [200, {"Content-Type"=>"text/html"}, ["<h1>hello</h1>"]]
  end

  rack_app4 = proc do |env; req, resp|
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


if flag_jetrouter

  jet_router = proc {
    handler1 = proc {|env|
      [200, {"Content-Type"=>"text/html"}, ["<h1>hello</h1>"]]
    }
    handler2 = proc {|env|
      d = env['rack.urlpath_params']
      [200, {"Content-Type"=>"text/html"}, ["<h1>id=#{d['id']}</h1>"]]
    }
    handler3 = proc {|env|
      d = env['rack.urlpath_params']
      [200, {"Content-Type"=>"text/html"}, ["<h1>id=#{d['id']}, comment_id=#{d['comment_id']}</h1>"]]
    }
    mapping = [
      ['/api', ENTRIES.each_with_object([]) {|x, arr|
                 arr << ["/#{x}", [
                           ['',      handler1],
                           ['/:id',  handler2],
                         ]]
                 arr << ["/#{x}/:id/comments", [
                           ['/:comment_id',  handler3],
                         ]]
               },
      ],
    ]
    opts = {
      cache_size:     ($opt_k8cache || 0).to_i,
      _enable_range:  $opt_k8range != '0',
      #prefix_minlength_target: /\A\/api\/\w/,
    }
    Rack::JetRouter.new(mapping, **opts)
  }.call()

end


if flag_multiplexer

  mpx_app = Rack::Multiplexer.new().tap do |app|
    handler1 = proc {|env|
      [200, {"Content-Type"=>"text/html"}, ["<h1>hello</h1>"]]
    }
    handler2 = proc {|env|
      d = env['rack.request.query_hash']
      [200, {"Content-Type"=>"text/html"}, ["<h1>id=#{d['id']}</h1>"]]
    }
    handler3 = proc {|env|
      d = env['rack.request.query_hash']
      [200, {"Content-Type"=>"text/html"}, ["<h1>id=#{d['id']}, comment_id=#{d['comment_id']}</h1>"]]
    }
    ENTRIES.each do |x|
      app.get "/api/#{x}"     , handler1
      app.get "/api/#{x}/:id" , handler2
      app.get "/api/#{x}/:id/comments/:comment_id" , handler3
    end
  end

end


if flag_sinatra

  class SinaApp < Sinatra::Base
    ## run benchmarks without middlewares
    set :sessions   , false
    set :logging    , false
    set :protection , false
    set :x_cascade  , false
    #
    ENTRIES.each do |x|
      get "/api/#{x}"     do "<h1>hello</h1>" end
      get "/api/#{x}/:id" do "<h1>id=#{params['id']}</h1>" end
      get "/api/#{x}/:id/comments/:comment_id" do "<h1>id=#{params['id']}, comment_id=#{params['comment_id']}</h1>" end
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


begin
  Rack::MockRequest
rescue
  require 'rack'
end
$environ = Rack::MockRequest.env_for("http://localhost/", method: 'GET')
$environ.freeze

def newenv(path)
  env = $environ.dup
  env['PATH_INFO'] = path
  env
end


N = ($opt_N || 100000).to_i
title = "Router library benchmark"
Benchmarker.scope(title, width: 33, loop: 1, iter: 1, extra: 0, sleep: 0) do

  puts "** N=#{N}"
  puts ""

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
  if flag_multiplexer
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
    assert body == "<h1>hello</h1>" || \
           body == "<h1>id=123</h1>" || \
           body == "<h1>id=456</h1>" || \
           body == "<h1>id=123, comment_id=7</h1>" || \
           body == "<h1>id=456, comment_id=7</h1>", \
           "#{body.inspect}: unpexpected body"
  end

end
