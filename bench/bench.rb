# -*- coding: utf-8 -*-
# frozen_string_literal: true

##
## Usage:
##   $ gem install bundler
##   $ bundler install
##   $ ruby bench.rb -n 1000_000
##   $ ruby bench.rb -n 1000_000 --rack=0 --sinatra=0 --multiplexer=0 # --hanami=0 --jetrouter=0 --keight=0
##


$LOAD_PATH << File.absolute_path("../../lib", __FILE__)


require 'benchmarker'
Benchmarker.parse_cmdopts()


class GetFlag

  def initialize(defaults={})
    @flag_all = to_bool($opt_all)
    @defaults = defaults
    @output   = String.new
  end

  attr_reader :output

  def call(key, lib, &b)
    default = @defaults[key]
    default != nil  or
      raise KeyError.new(key.inspect)
    opt_val = eval "$opt_#{key}"
    arr = [to_bool(opt_val), @flag_all, default]
    flag = arr.find {|x| x != nil }
    #
    begin
      [lib].flatten.each do |x| require x end
    rescue LoadError
      flag = nil
    end
    #
    version = flag == false ? "(skipped)" \
            : flag == nil   ? "(not installed)" \
            : yield
    gem = [lib].flatten()[0].gsub('/', '-')
    @output << "** %-20s : %s\n" % [gem, version]
    #
    return flag
  end

  def to_bool(val, default=nil)
    case val
    when 'on' , 'true' , 'yes', '1'  ; return true
    when 'off', 'false', 'no' , '0'  ; return false
    else                             ; return default
    end
  end

end

get_flag = GetFlag.new(
  :rack        => true,
  :jet         => true,
 #:rocket      => true,
  :keight      => true,
  :hanami      => true,
  :httprouter  => true,
  :multiplexer => true,
  :sinatra     => true,
)


flag_rack        = get_flag.(:rack       , "rack"            ) { Rack.release }
#flag_rocket     = get_flag.(:rocket     , "rocketrouter"    ) { RocketRouter::VERSION }
flag_jet         = get_flag.(:jet        , "rack/jet_router" ) { Rack::JetRouter::RELEASE }
flag_keight      = get_flag.(:keight     , "keight"          ) { K8::RELEASE }
flag_hanami      = get_flag.(:hanami     , "hanami/router"   ) { Hanami::Router::VERSION }
flag_httprouter  = get_flag.(:httprouter , "http_router"     ) { require "http_router/version"; HttpRouter::VERSION }
flag_multiplexer = get_flag.(:multiplexer, "rack/multiplexer") { Rack::Multiplexer::VERSION }
flag_sinatra     = get_flag.(:sinatra    , "sinatra/base"    ) { Sinatra::VERSION }


ENTRIES = ('a'..'z').map.with_index {|x, i| "%s%02d" % [x*3, i+1] }

target_urlpaths = [
  "/api/aaa01",
  "/api/aaa01/123",
#  "/api/aaa01/123/comments/7",
  "/api/zzz26",
  "/api/zzz26/456",
#  "/api/zzz26/456/comments/7",
]


def generate_apps(env_key, key_class)
  if    key_class == String ; id, c_id = 'id', 'c_id'
  elsif key_class == Symbol ; id, c_id = :id, :c_id
  else                      ; raise "** internal error: key_class=#{key_class.inspect}"
  end
  index_app = proc {|env|
    [200, {"Content-Type"=>"text/html"}, ["<h1>hello</h1>"]]
  }
  show_app = proc {|env|
    d = env[env_key]
    [200, {"Content-Type"=>"text/html"}, ["<h1>id=#{d[id]}</h1>"]]
  }
  comment_app = proc {|env|
    d = env[env_key]
    [200, {"Content-Type"=>"text/html"}, ["<h1>id=#{d[id]}, c_id=#{d[c_id]}</h1>"]]
  }
  return index_app, show_app, comment_app
end


def let(*args)
  return (yield *args)
end


rack_app = flag_rack && let() {
  #proc do |env|
  #  [200, {"Content-Type"=>"text/html"}, ["<h1>hello</h1>"]]
  #end
  proc do |env; req, resp|
    req  = Rack::Request.new(env)
    resp = Rack::Response.new
    #[resp.status, resp.headers, ["<h1>hello</h1>"]]
    #[200, {"Content-Type"=>"text/html"}, ["<h1>hello</h1>"]]
    resp.status = 200
    resp.headers["Content-Type"] = "text/html"
    resp.write("<h1>hello</h1>")
    resp.finish()
  end
}


jet_app = flag_jet && let() {
  index_app, show_app, comment_app = generate_apps('rack.urlpath_params', String)
  mapping = {
    '/api' => ENTRIES.each_with_object({}) {|x, map|
                map.update({
                  "/#{x}" => {
                    ""             => index_app,
                    "/:id"         => show_app,
                  },
                  "/#{x}/:id/comments" => {
                    "/:comment_id" => comment_app,
                  },
                })
              },
  }
  opts = {
    cache_size:     0,
    _enable_range:  true,
    #prefix_minlength_target: /\A\/api\/\w/,
  }
  Rack::JetRouter.new(mapping, **opts)
}


multiplexer_app = flag_multiplexer && let() {
  index_app, show_app, comment_app = generate_apps('rack.request.query_hash', String)
  Rack::Multiplexer.new().tap do |app|
    ENTRIES.each do |x|
      app.get "/api/#{x}"     , index_app
      app.get "/api/#{x}/:id" , show_app
      app.get "/api/#{x}/:id/comments/:comment_id" , comment_app
    end
  end
}


sinatra_app = flag_sinatra && let() {
  class SinaApp < Sinatra::Base
    ## run benchmarks without middlewares
    set :sessions   , false
    set :logging    , false
    set :protection , false
    set :x_cascade  , false
    #
    ENTRIES.each do |x|
      get "/api/#{x}" do
        "<h1>hello</h1>"
      end
      get "/api/#{x}/:id" do
        "<h1>id=#{params['id']}</h1>"
      end
      get "/api/#{x}/:id/comments/:comment_id" do
        "<h1>id=#{params['id']}, comment_id=#{params['comment_id']}</h1>"
      end
    end
  end
  SinaApp.new
}


keight_app = flag_keight && let() {
  class K8HelloAction < K8::Action
    mapping '',       :GET=>:do_index
    mapping '/{id}',  :GET=>:do_show
    def do_index()
      "<h1>hello</h1>"
    end
    def do_show(id)
      "<h1>id=#{id.inspect}</h1>"
    end
  end
  class K8CommentAction < K8::Action
    mapping '/{comment_id}',  :GET=>:do_show
    def do_show(id, comment_id)
      "<h1>id=#{id}, comment_id=#{comment_id}</h1>"
    end
  end
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
}


hanami_app = flag_hanami && let() {
  ## ref: https://github.com/hanami/router
  index_app, show_app, comment_app = generate_apps('router.params', Symbol)
  Hanami::Router.new do
    scope "api" do
      ENTRIES.each do |x|
        get "/#{x}"    , to: index_app
        get "/#{x}/:id", to: show_app
        get "/#{x}/:id/comments/:comment_id", to: comment_app
      end
    end
  end
}


httprouter_app = flag_httprouter && let() {
  require 'uri'
  require 'cgi'
  class <<URI
    #alias unescape decode_www_form
    def unescape(x)
      CGI.unescape(x)
    end
  end
  #
  index_app, show_app, comment_app = generate_apps('router.params', Symbol)
  HttpRouter.new.tap do |r|
    ENTRIES.each do |x|
      r.add("/api/#{x}"    ).to(index_app)
      r.add("/api/#{x}/:id").to(show_app)
      r.add("/api/#{x}/:id/comments/:comment_id").to(comment_app)
    end
  end
}


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


N = Benchmarker::OPTIONS.delete(:loop) || 1000_000
title = "Router library benchmark"
width = target_urlpaths.collect(&:length).max()
Benchmarker.scope(title, width: width + 17, loop: 1, iter: 1, extra: 0, sleep: 0) do

  puts get_flag.output()
  puts "** N=#{N}"
  puts ""

  ### empty task
  task nil do
    i = 0; n = N
    while (i += 1) <= n
      #newenv("/api")
    end
  end

  ### Rack
  #flag_rack and target_urlpaths.each do |x|
  #  rack_app.call(newenv(x))               # warm up
  #  task "(Rack plain app) #{x}" do        # no routing
  #    env = newenv(x)
  #    i = 0; n = N
  #    while (i += 1) <= n
  #      tuple = rack_app.call(env)
  #    end
  #    tuple
  #  end
  #end
  flag_rack and target_urlpaths.each do |x|
    rack_app.call(newenv(x))               # warm up
    task "(Rack::Req+Res)  #{x}" do        # no routing
      env = newenv(x)
      i = 0; n = N
      while (i += 1) <= n
        tuple = rack_app.call(env)
      end
      tuple
    end
  end

  ### Rack::JetRouter
  flag_jet and target_urlpaths.each do |x|
    jet_app.call(newenv(x))                # warm up
    task "(JetRouter)      #{x}" do
      env = newenv(x)
      i = 0; n = N
      while (i += 1) <= n
        tuple = jet_app.call(env)
      end
      tuple
    end
  end

  ### Keight
  flag_keight and target_urlpaths.each do |x|
    keight_app.call(newenv(x))             # warm up
    task "(Keight)         #{x}" do
      env = newenv(x)
      i = 0; n = N
      while (i += 1) <= n
        tuple = keight_app.call(env)
      end
      tuple
    end
  end

  ### Hanami::Router
  flag_hanami and target_urlpaths.each do |x|
    hanami_app.call(newenv(x))             # warm up
    task "(Hanami::Router) #{x}" do
      env = newenv(x)
      i = 0; n = N
      while (i += 1) <= n
        tuple = hanami_app.call(env)
      end
      tuple
    end
  end

  ### HttpRouter
  flag_httprouter and target_urlpaths.each do |path|
    httprouter_app.call(newenv(path))      # warm up
    task "(HttpRouter)     #{path}" do
      env = newenv(path)
      i = 0; n = N
      while (i += 1) <= n
        result = httprouter_app.call(env)
        #result = httprouter_app.route(path)
      end
      result
    end
  end

  ### Rack::Multiplexer
  flag_multiplexer and target_urlpaths.each do |x|
    multiplexer_app.call(newenv(x))        # warm up
    task "(Multiplexer)    #{x}" do
      env = newenv(x)
      i = 0; n = N
      while (i += 1) <= n
        tuple = multiplexer_app.call(env)
      end
      tuple
    end
  end

  ### Sinatra
  flag_sinatra and target_urlpaths.each do |x|
    sinatra_app.call(newenv(x))            # warm up
    task "(Sinatra)        #{x}" do
      env = newenv(x)
      i = 0; n = N
      while (i += 1) <= n
        tuple = sinatra_app.call(env)
      end
      tuple
    end
  end

  ## validation
  validate do |val|   # or: validate do |val, task_name, tag|
    tuple = val
    assert tuple[0] == 200, "Expected 200 but got #{tuple[0]}"
    body = tuple[2].each {|x| break x }
    expected_bodies = [
      "<h1>hello</h1>",
      "<h1>id=123</h1>",
      "<h1>id=456</h1>",
      "<h1>id=123, comment_id=7</h1>",
      "<h1>id=456, comment_id=7</h1>",
    ]
    assert expected_bodies.include?(body), "#{body.inspect}: Unpexpected body."
  end

end
