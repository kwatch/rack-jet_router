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

$ ruby -I../lib -s bench.rb -N=1000000
benchmarker.rb:   release 1.0.0
RUBY_VERSION:     2.3.1
RUBY_PATCHLEVEL:  112
RUBY_PLATFORM:    x86_64-darwin15

** rack            : 1.6.4
** rack-jet_router : 1.2.0
** rack-multiplexer: 0.0.8
** sinatra         : 1.4.6
** keight          : 0.3.0
** hanami          : 0.8.0

** N=1000000

##                                     user       sys     total      real
(Empty)                              7.1500    0.0700    7.2200    7.2258
(Rack plain)  /api/aaa01             0.9200    0.0200    0.9400    0.9316
(Rack plain)  /api/aaa01/123         1.0000    0.0100    1.0100    1.0222
(Rack plain)  /api/zzz26             0.9300    0.0000    0.9300    0.9435
(Rack plain)  /api/zzz26/789         0.9700    0.0200    0.9900    0.9930
(R::Req+Res)  /api/aaa01            10.7400    0.0300   10.7700   10.7835
(R::Req+Res)  /api/aaa01/123        10.8000    0.0300   10.8300   10.8412
(R::Req+Res)  /api/zzz26            10.6800    0.0200   10.7000   10.7116
(R::Req+Res)  /api/zzz26/789        10.7000    0.0300   10.7300   10.7423
(JetRouter)   /api/aaa01             1.4100    0.0100    1.4200    1.4191
(JetRouter)   /api/aaa01/123         5.9500    0.0500    6.0000    6.0146
(JetRouter)   /api/zzz26             1.4300    0.0100    1.4400    1.4300
(JetRouter)   /api/zzz26/789         6.8500    0.0500    6.9000    6.9102
(Multiplexer) /api/aaa01             6.0400    0.0500    6.0900    6.1026
(Multiplexer) /api/aaa01/123        18.5500    0.1300   18.6800   18.6987
(Multiplexer) /api/zzz26            29.9300    0.3500   30.2800   30.7618
(Multiplexer) /api/zzz26/789        42.2300    0.1900   42.4200   42.6660
(Sinatra)     /api/aaa01            90.4900   19.1600  109.6500  109.7597
(Sinatra)     /api/aaa01/123       101.5600   19.5900  121.1500  121.3258
(Sinatra)     /api/zzz26           132.6700   19.6400  152.3100  152.5214
(Sinatra)     /api/zzz26/789       142.5800   19.7100  162.2900  162.4510
(Keight.rb)   /api/aaa01             7.2100    0.0200    7.2300    7.2330
(Keight.rb)   /api/aaa01/123        10.8000    0.0500   10.8500   10.8708
(Keight.rb)   /api/zzz26             7.1400    0.0200    7.1600    7.1772
(Keight.rb)   /api/zzz26/789        11.4800    0.0400   11.5200   11.5314
(Hanami::Router) /api/aaa01         11.6900   -0.0100   11.6800   11.7033
(Hanami::Router) /api/aaa01/123     17.8700    0.0200   17.8900   17.9229
(Hanami::Router) /api/zzz26         11.5200   -0.0100   11.5100   11.5185
(Hanami::Router) /api/zzz26/789     17.4300   -0.0100   17.4200   17.4462

## Ranking                             real
(Rack plain)  /api/aaa01             0.9316 (100.0%) ********************
(Rack plain)  /api/zzz26             0.9435 ( 98.7%) ********************
(Rack plain)  /api/zzz26/789         0.9930 ( 93.8%) *******************
(Rack plain)  /api/aaa01/123         1.0222 ( 91.1%) ******************
(JetRouter)   /api/aaa01             1.4191 ( 65.6%) *************
(JetRouter)   /api/zzz26             1.4300 ( 65.1%) *************
(JetRouter)   /api/aaa01/123         6.0146 ( 15.5%) ***
(Multiplexer) /api/aaa01             6.1026 ( 15.3%) ***
(JetRouter)   /api/zzz26/789         6.9102 ( 13.5%) ***
(Keight.rb)   /api/zzz26             7.1772 ( 13.0%) ***
(Keight.rb)   /api/aaa01             7.2330 ( 12.9%) ***
(R::Req+Res)  /api/zzz26            10.7116 (  8.7%) **
(R::Req+Res)  /api/zzz26/789        10.7423 (  8.7%) **
(R::Req+Res)  /api/aaa01            10.7835 (  8.6%) **
(R::Req+Res)  /api/aaa01/123        10.8412 (  8.6%) **
(Keight.rb)   /api/aaa01/123        10.8708 (  8.6%) **
(Hanami::Router) /api/zzz26         11.5185 (  8.1%) **
(Keight.rb)   /api/zzz26/789        11.5314 (  8.1%) **
(Hanami::Router) /api/aaa01         11.7033 (  8.0%) **
(Hanami::Router) /api/zzz26/789     17.4462 (  5.3%) *
(Hanami::Router) /api/aaa01/123     17.9229 (  5.2%) *
(Multiplexer) /api/aaa01/123        18.6987 (  5.0%) *
(Multiplexer) /api/zzz26            30.7618 (  3.0%) *
(Multiplexer) /api/zzz26/789        42.6660 (  2.2%) 
(Sinatra)     /api/aaa01           109.7597 (  0.8%) 
(Sinatra)     /api/aaa01/123       121.3258 (  0.8%) 
(Sinatra)     /api/zzz26           152.5214 (  0.6%) 
(Sinatra)     /api/zzz26/789       162.4510 (  0.6%) 

## Matrix                              real     [01]     [02]     [03]     [04]     [05]     [06]     [07]     [08]     [09]     [10]     [11]     [12]     [13]     [14]     [15]     [16]     [17]     [18]     [19]     [20]     [21]     [22]     [23]     [24]     [25]     [26]     [27]     [28]
[01] (Rack plain)  /api/aaa01        0.9316   100.0%   101.3%   106.6%   109.7%   152.3%   153.5%   645.6%   655.1%   741.8%   770.5%   776.4%  1149.9%  1153.2%  1157.6%  1163.8%  1167.0%  1236.5%  1237.9%  1256.3%  1872.8%  1924.0%  2007.3%  3302.2%  4580.1% 11782.4% 13024.0% 16372.7% 17438.6%
[02] (Rack plain)  /api/zzz26        0.9435    98.7%   100.0%   105.2%   108.3%   150.4%   151.6%   637.5%   646.8%   732.4%   760.7%   766.6%  1135.3%  1138.5%  1142.9%  1149.0%  1152.2%  1220.8%  1222.2%  1240.4%  1849.0%  1899.6%  1981.8%  3260.3%  4522.0% 11633.0% 12858.8% 16165.1% 17217.5%
[03] (Rack plain)  /api/zzz26/789    0.9930    93.8%    95.0%   100.0%   102.9%   142.9%   144.0%   605.7%   614.6%   695.9%   722.8%   728.4%  1078.7%  1081.8%  1086.0%  1091.8%  1094.8%  1160.0%  1161.3%  1178.6%  1757.0%  1805.0%  1883.1%  3097.9%  4296.8% 11053.6% 12218.4% 15360.0% 16360.0%
[04] (Rack plain)  /api/aaa01/123    1.0222    91.1%    92.3%    97.1%   100.0%   138.8%   139.9%   588.4%   597.0%   676.0%   702.1%   707.6%  1047.9%  1050.9%  1054.9%  1060.5%  1063.4%  1126.8%  1128.1%  1144.9%  1706.7%  1753.3%  1829.2%  3009.3%  4173.8% 10737.2% 11868.7% 14920.4% 15891.7%
[05] (JetRouter)   /api/aaa01        1.4191    65.6%    66.5%    70.0%    72.0%   100.0%   100.8%   423.8%   430.0%   486.9%   505.8%   509.7%   754.8%   757.0%   759.9%   763.9%   766.0%   811.7%   812.6%   824.7%  1229.4%  1263.0%  1317.6%  2167.7%  3006.5%  7734.4%  8549.4% 10747.6% 11447.3%
[06] (JetRouter)   /api/zzz26        1.4300    65.1%    66.0%    69.4%    71.5%    99.2%   100.0%   420.6%   426.8%   483.2%   501.9%   505.8%   749.1%   751.2%   754.1%   758.1%   760.2%   805.5%   806.4%   818.4%  1220.0%  1253.4%  1307.6%  2151.2%  2983.7%  7675.7%  8484.6% 10666.2% 11360.6%
[07] (JetRouter)   /api/aaa01/123    6.0146    15.5%    15.7%    16.5%    17.0%    23.6%    23.8%   100.0%   101.5%   114.9%   119.3%   120.3%   178.1%   178.6%   179.3%   180.2%   180.7%   191.5%   191.7%   194.6%   290.1%   298.0%   310.9%   511.5%   709.4%  1824.9%  2017.2%  2535.9%  2701.0%
[08] (Multiplexer) /api/aaa01        6.1026    15.3%    15.5%    16.3%    16.8%    23.3%    23.4%    98.6%   100.0%   113.2%   117.6%   118.5%   175.5%   176.0%   176.7%   177.6%   178.1%   188.7%   189.0%   191.8%   285.9%   293.7%   306.4%   504.1%   699.1%  1798.6%  1988.1%  2499.3%  2662.0%
[09] (JetRouter)   /api/zzz26/789    6.9102    13.5%    13.7%    14.4%    14.8%    20.5%    20.7%    87.0%    88.3%   100.0%   103.9%   104.7%   155.0%   155.5%   156.1%   156.9%   157.3%   166.7%   166.9%   169.4%   252.5%   259.4%   270.6%   445.2%   617.4%  1588.4%  1755.7%  2207.2%  2350.9%
[10] (Keight.rb)   /api/zzz26        7.1772    13.0%    13.1%    13.8%    14.2%    19.8%    19.9%    83.8%    85.0%    96.3%   100.0%   100.8%   149.2%   149.7%   150.2%   151.0%   151.5%   160.5%   160.7%   163.1%   243.1%   249.7%   260.5%   428.6%   594.5%  1529.3%  1690.4%  2125.1%  2263.4%
[11] (Keight.rb)   /api/aaa01        7.2330    12.9%    13.0%    13.7%    14.1%    19.6%    19.8%    83.2%    84.4%    95.5%    99.2%   100.0%   148.1%   148.5%   149.1%   149.9%   150.3%   159.2%   159.4%   161.8%   241.2%   247.8%   258.5%   425.3%   589.9%  1517.5%  1677.4%  2108.7%  2246.0%
[12] (R::Req+Res)  /api/zzz26       10.7116     8.7%     8.8%     9.3%     9.5%    13.2%    13.3%    56.2%    57.0%    64.5%    67.0%    67.5%   100.0%   100.3%   100.7%   101.2%   101.5%   107.5%   107.7%   109.3%   162.9%   167.3%   174.6%   287.2%   398.3%  1024.7%  1132.7%  1423.9%  1516.6%
[13] (R::Req+Res)  /api/zzz26/789   10.7423     8.7%     8.8%     9.2%     9.5%    13.2%    13.3%    56.0%    56.8%    64.3%    66.8%    67.3%    99.7%   100.0%   100.4%   100.9%   101.2%   107.2%   107.3%   108.9%   162.4%   166.8%   174.1%   286.4%   397.2%  1021.7%  1129.4%  1419.8%  1512.2%
[14] (R::Req+Res)  /api/aaa01       10.7835     8.6%     8.7%     9.2%     9.5%    13.2%    13.3%    55.8%    56.6%    64.1%    66.6%    67.1%    99.3%    99.6%   100.0%   100.5%   100.8%   106.8%   106.9%   108.5%   161.8%   166.2%   173.4%   285.3%   395.7%  1017.8%  1125.1%  1414.4%  1506.5%
[15] (R::Req+Res)  /api/aaa01/123   10.8412     8.6%     8.7%     9.2%     9.4%    13.1%    13.2%    55.5%    56.3%    63.7%    66.2%    66.7%    98.8%    99.1%    99.5%   100.0%   100.3%   106.2%   106.4%   108.0%   160.9%   165.3%   172.5%   283.7%   393.6%  1012.4%  1119.1%  1406.9%  1498.5%
[16] (Keight.rb)   /api/aaa01/123   10.8708     8.6%     8.7%     9.1%     9.4%    13.1%    13.2%    55.3%    56.1%    63.6%    66.0%    66.5%    98.5%    98.8%    99.2%    99.7%   100.0%   106.0%   106.1%   107.7%   160.5%   164.9%   172.0%   283.0%   392.5%  1009.7%  1116.1%  1403.0%  1494.4%
[17] (Hanami::Router) /api/zzz26    11.5185     8.1%     8.2%     8.6%     8.9%    12.3%    12.4%    52.2%    53.0%    60.0%    62.3%    62.8%    93.0%    93.3%    93.6%    94.1%    94.4%   100.0%   100.1%   101.6%   151.5%   155.6%   162.3%   267.1%   370.4%   952.9%  1053.3%  1324.1%  1410.3%
[18] (Keight.rb)   /api/zzz26/789   11.5314     8.1%     8.2%     8.6%     8.9%    12.3%    12.4%    52.2%    52.9%    59.9%    62.2%    62.7%    92.9%    93.2%    93.5%    94.0%    94.3%    99.9%   100.0%   101.5%   151.3%   155.4%   162.2%   266.8%   370.0%   951.8%  1052.1%  1322.7%  1408.8%
[19] (Hanami::Router) /api/aaa01    11.7033     8.0%     8.1%     8.5%     8.7%    12.1%    12.2%    51.4%    52.1%    59.0%    61.3%    61.8%    91.5%    91.8%    92.1%    92.6%    92.9%    98.4%    98.5%   100.0%   149.1%   153.1%   159.8%   262.8%   364.6%   937.9%  1036.7%  1303.2%  1388.1%
[20] (Hanami::Router) /api/zzz26/789   17.4462     5.3%     5.4%     5.7%     5.9%     8.1%     8.2%    34.5%    35.0%    39.6%    41.1%    41.5%    61.4%    61.6%    61.8%    62.1%    62.3%    66.0%    66.1%    67.1%   100.0%   102.7%   107.2%   176.3%   244.6%   629.1%   695.4%   874.2%   931.2%
[21] (Hanami::Router) /api/aaa01/123   17.9229     5.2%     5.3%     5.5%     5.7%     7.9%     8.0%    33.6%    34.0%    38.6%    40.0%    40.4%    59.8%    59.9%    60.2%    60.5%    60.7%    64.3%    64.3%    65.3%    97.3%   100.0%   104.3%   171.6%   238.1%   612.4%   676.9%   851.0%   906.4%
[22] (Multiplexer) /api/aaa01/123   18.6987     5.0%     5.0%     5.3%     5.5%     7.6%     7.6%    32.2%    32.6%    37.0%    38.4%    38.7%    57.3%    57.4%    57.7%    58.0%    58.1%    61.6%    61.7%    62.6%    93.3%    95.9%   100.0%   164.5%   228.2%   587.0%   648.8%   815.7%   868.8%
[23] (Multiplexer) /api/zzz26       30.7618     3.0%     3.1%     3.2%     3.3%     4.6%     4.6%    19.6%    19.8%    22.5%    23.3%    23.5%    34.8%    34.9%    35.1%    35.2%    35.3%    37.4%    37.5%    38.0%    56.7%    58.3%    60.8%   100.0%   138.7%   356.8%   394.4%   495.8%   528.1%
[24] (Multiplexer) /api/zzz26/789   42.6660     2.2%     2.2%     2.3%     2.4%     3.3%     3.4%    14.1%    14.3%    16.2%    16.8%    17.0%    25.1%    25.2%    25.3%    25.4%    25.5%    27.0%    27.0%    27.4%    40.9%    42.0%    43.8%    72.1%   100.0%   257.3%   284.4%   357.5%   380.8%
[25] (Sinatra)     /api/aaa01      109.7597     0.8%     0.9%     0.9%     0.9%     1.3%     1.3%     5.5%     5.6%     6.3%     6.5%     6.6%     9.8%     9.8%     9.8%     9.9%     9.9%    10.5%    10.5%    10.7%    15.9%    16.3%    17.0%    28.0%    38.9%   100.0%   110.5%   139.0%   148.0%
[26] (Sinatra)     /api/aaa01/123  121.3258     0.8%     0.8%     0.8%     0.8%     1.2%     1.2%     5.0%     5.0%     5.7%     5.9%     6.0%     8.8%     8.9%     8.9%     8.9%     9.0%     9.5%     9.5%     9.6%    14.4%    14.8%    15.4%    25.4%    35.2%    90.5%   100.0%   125.7%   133.9%
[27] (Sinatra)     /api/zzz26      152.5214     0.6%     0.6%     0.7%     0.7%     0.9%     0.9%     3.9%     4.0%     4.5%     4.7%     4.7%     7.0%     7.0%     7.1%     7.1%     7.1%     7.6%     7.6%     7.7%    11.4%    11.8%    12.3%    20.2%    28.0%    72.0%    79.5%   100.0%   106.5%
[28] (Sinatra)     /api/zzz26/789  162.4510     0.6%     0.6%     0.6%     0.6%     0.9%     0.9%     3.7%     3.8%     4.3%     4.4%     4.5%     6.6%     6.6%     6.6%     6.7%     6.7%     7.1%     7.1%     7.2%    10.7%    11.0%    11.5%    18.9%    26.3%    67.6%    74.7%    93.9%   100.0%
