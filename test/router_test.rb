# -*- coding: utf-8 -*-

###
### $Release: 0.0.0 $
### $Copyright: copyright(c) 2015 kwatch@gmail.com $
### $License: MIT License $
###

require_relative './shared'


Oktest.scope do


  topic Rack::JetRouter do

    welcome_app      = proc {|env| [200, {}, ["welcome_app"]]}
    #
    book_list_api    = proc {|env| [200, {}, ["book_list_api"]]}
    book_create_api  = proc {|env| [200, {}, ["book_create_api"]]}
    book_new_api     = proc {|env| [200, {}, ["book_new_api"]]}
    book_show_api    = proc {|env| [200, {}, ["book_show_api"]]}
    book_update_api  = proc {|env| [200, {}, ["book_update_api"]]}
    book_delete_api  = proc {|env| [200, {}, ["book_delete_api"]]}
    book_edit_api    = proc {|env| [200, {}, ["book_edit_api"]]}
    #
    comment_create_api     = proc {|env| [200, {}, ["comment_create_api"]]}
    comment_update_api     = proc {|env| [200, {}, ["comment_update_api"]]}
    #
    admin_book_list_app    = proc {|env| [200, {}, ["admin_book_list_app"]]}
    admin_book_create_app  = proc {|env| [200, {}, ["admin_book_create_app"]]}
    admin_book_new_app     = proc {|env| [200, {}, ["admin_book_new_app"]]}
    admin_book_show_app    = proc {|env| [200, {}, ["admin_book_show_app"]]}
    admin_book_update_app  = proc {|env| [200, {}, ["admin_book_update_app"]]}
    admin_book_delete_app  = proc {|env| [200, {}, ["admin_book_delete_app"]]}
    admin_book_edit_app    = proc {|env| [200, {}, ["admin_book_edit_app"]]}
    #
    whole_urlpath_mapping = [
      ['/'              , welcome_app],
      ['/index.html'    , welcome_app],
      ['/api'           , [
        ['/books'       , [
          [''           , book_list_api],
          ['/new'       , book_new_api],
          ['/:id'       , book_show_api],
          ['/:id/edit'  , book_edit_api],
        ]],
        ['/books/:book_id/comments', [
          [''             , comment_create_api],
          ['/:comment_id' , comment_update_api],
        ]],
      ]],
      ['/admin'         , [
        ['/books'       , [
          [''           , {:GET=>admin_book_list_app, :POST=>admin_book_create_app}],
          ['/:id'       , {:GET=>admin_book_show_app, :PUT=>admin_book_update_app, :DELETE=>admin_book_delete_app}],
        ]],
      ]],
    ]

    def new_env(req_method, req_path, opts={})
      opts[:method] = req_method.to_s
      env = ::Rack::MockRequest.env_for(req_path, opts)
      return env
    end

    before do
      @router = Rack::JetRouter.new(whole_urlpath_mapping)
    end


    topic '#normalize_method_mapping()' do

      spec "[!r7cmk] converts keys into string." do
        d1 = {GET: book_list_api, POST: book_create_api}
        d2 = @router.normalize_method_mapping(d1)
        ok {d2} == {"GET"=>book_list_api, "POST"=>book_create_api}
        #
        mapping = [
          ['/books', {:GET=>book_list_api, :POST=>book_create_api}]
        ]
        Rack::JetRouter.new(mapping).instance_exec(self) do |_|
          dict = @fixed_endpoints
          _.ok {dict['/books']} == {'GET'=>book_list_api, 'POST'=>book_create_api}
        end
      end

      spec "[!z9kww] allows 'ANY' as request method." do
        d1 = {ANY: book_list_api, POST: book_create_api}
        d2 = @router.normalize_method_mapping(d1)
        ok {d2} == {"ANY"=>book_list_api, "POST"=>book_create_api}
        #
        mapping = [
          ['/books', {'ANY'=>book_list_api, 'POST'=>book_create_api}]
        ]
        Rack::JetRouter.new(mapping).instance_exec(self) do |_|
          dict = @fixed_endpoints
          _.ok {dict['/books']} == {'ANY'=>book_list_api, 'POST'=>book_create_api}
        end
      end

      spec "[!k7sme] raises error when unknown request method specified." do
        d1 = {LOCK: book_list_api}
        pr = proc { @router.normalize_method_mapping(d1) }
        ok {pr}.raise?(ArgumentError, 'LOCK: unknown request method.')
        #
        mapping = [
          ['/books', {UNLOCK: book_list_api}]
        ]
        pr = proc { Rack::JetRouter.new(mapping) }
        ok {pr}.raise?(ArgumentError, 'UNLOCK: unknown request method.')
      end

      spec "[!itfsd] returns new Hash object." do
        d1 = {"GET" => book_list_api}
        d2 = @router.normalize_method_mapping(d1)
        ok {d2} == d1
        ok {d2}.NOT.same?(d1)
      end

      spec "[!gd08f] if arg is an instance of Hash subclass, returns new instance of it." do
        d1 = Map(GET: book_list_api)
        d2 = @router.normalize_method_mapping(d1)
        ok {d2}.is_a?(Map)
        ok {d2} == Map.new.update({"GET"=>book_list_api})
      end

    end


    topic '#param2rexp()' do

      spec "[!6sd9b] returns regexp string according to param name." do
        ok {@router.param2rexp("id")}       == '[^./?]+'
        ok {@router.param2rexp("user_id")}  == '[^./?]+'
        ok {@router.param2rexp("username")} == '[^./?]+'
      end

      spec "[!rfvk2] returns '\d+' if param name matched to int param regexp." do
        router = Rack::JetRouter.new([], int_param: /(\A|_)id\z/)
        ok {router.param2rexp("id")}       == '\d+'
        ok {router.param2rexp("user_id")}  == '\d+'
        ok {router.param2rexp("username")} == '[^./?]+'
      end

    end


    topic '#should_redirect?' do

      spec "[!dsu34] returns false when request path is '/'." do
        @router.instance_exec(self) do |_|
          _.ok {should_redirect?(_.new_env('GET'   , '/'))} == false
          _.ok {should_redirect?(_.new_env('POST'  , '/'))} == false
          _.ok {should_redirect?(_.new_env('PUT'   , '/'))} == false
          _.ok {should_redirect?(_.new_env('DELETE', '/'))} == false
          _.ok {should_redirect?(_.new_env('HEAD'  , '/'))} == false
          _.ok {should_redirect?(_.new_env('PATCH' , '/'))} == false
        end
      end

      spec "[!ycpqj] returns true when request method is GET or HEAD." do
        @router.instance_exec(self) do |_|
          _.ok {should_redirect?(_.new_env('GET'   , '/index'))} == true
          _.ok {should_redirect?(_.new_env('HEAD'  , '/index'))} == true
        end
      end

      spec "[!7q8xu] returns false when request method is POST, PUT or DELETE." do
        @router.instance_exec(self) do |_|
          _.ok {should_redirect?(_.new_env('POST'  , '/index'))} == false
          _.ok {should_redirect?(_.new_env('PUT'   , '/index'))} == false
          _.ok {should_redirect?(_.new_env('DELETE', '/index'))} == false
          _.ok {should_redirect?(_.new_env('PATCH' , '/index'))} == false
        end
      end

    end


    topic '#error_not_found()' do

      spec "[!mlruv] returns 404 response." do
        expected = [404, {"Content-Type"=>"text/plain"}, ["404 Not Found"]]
        env = new_env('GET', '/xxx')
        @router.instance_exec(self) do |_|
          _.ok {error_not_found(env)} == expected
        end
      end

    end


    topic '#error_not_allowed()' do

      spec "[!mjigf] returns 405 response." do
        expected = [405, {"Content-Type"=>"text/plain"}, ["405 Method Not Allowed"]]
        env = new_env('POST', '/')
        @router.instance_exec(self) do |_|
          _.ok {error_not_allowed(env)} == expected
        end
      end

    end


    topic '#initialize()' do

      spec "[!21mf9] 'urlpath_cache_size:' kwarg is available for backward compatibility." do
        r = Rack::JetRouter.new([], urlpath_cache_size: 5)
        ok {r.instance_variable_get(:@cache_size)} == 5
        ok {r.instance_variable_get(:@cache_dict)} == {}
        #
        r = Rack::JetRouter.new([], cache_size: 7)
        ok {r.instance_variable_get(:@cache_size)} == 7
        ok {r.instance_variable_get(:@cache_dict)} == {}
      end

      spec "[!5tw57] cache is disabled when 'cache_size:' is zero." do
        r = Rack::JetRouter.new([], cache_size: 0)
        ok {r.instance_variable_get(:@cache_size)} == 0
        ok {r.instance_variable_get(:@cache_dict)} == nil
        #
        r = Rack::JetRouter.new([], urlpath_cache_size: 0)
        ok {r.instance_variable_get(:@cache_size)} == 0
        ok {r.instance_variable_get(:@cache_dict)} == nil
        #
        r = Rack::JetRouter.new([])
        ok {r.instance_variable_get(:@cache_size)} == 0
        ok {r.instance_variable_get(:@cache_dict)} == nil
      end

      spec "[!x2l32] gathers all endpoints." do
        all = @router.instance_eval { @all_endpoints }
        ok {all} == [
          ["/"                  , welcome_app],
          ["/index.html"        , welcome_app],
          ["/api/books"         , book_list_api],
          ["/api/books/new"     , book_new_api],
          ["/api/books/:id"     , book_show_api],
          ["/api/books/:id/edit", book_edit_api],
          ["/api/books/:book_id/comments"            , comment_create_api],
          ["/api/books/:book_id/comments/:comment_id", comment_update_api],
          ["/admin/books", {
             "GET"    => admin_book_list_app,
             "POST"   => admin_book_create_app,
           }],
          ["/admin/books/:id", {
             "GET"    => admin_book_show_app,
             "PUT"    => admin_book_update_app,
             "DELETE" => admin_book_delete_app,
           }],
        ]
      end

      spec "[!l63vu] handles urlpath pattern as fixed when no urlpath params." do
        @router.instance_exec(self) do |_|
          _.ok {@fixed_endpoints} == {
            '/'                => welcome_app,
            '/index.html'      => welcome_app,
            '/api/books'       => book_list_api,
            '/api/books/new'   => book_new_api,
            '/admin/books'     => {
              'GET'=>admin_book_list_app,
              'POST'=>admin_book_create_app,
            }
          }
        end
        #
        mapping = [
          ['/api/books'      , book_list_api],
        ]
        router = Rack::JetRouter.new(mapping)
        router.instance_exec(self) do |_|
          _.ok {@fixed_endpoints} == {'/api/books' => book_list_api}
          _.ok {@variable_endpoints} == []
        end
      end

      spec "[!saa1a] compiles compound urlpath regexp." do
        id = '[^./?]+'
        z  = '(\z)'
        ok {@router.urlpath_rexp} == %r!\A/a(?:pi/books/#{id}(?:#{z}|/(?:edit#{z}|comments(?:#{z}|/#{id}#{z})))|dmin/books/#{id}#{z})\z!
      end

      spec "[!f1d7s] builds variable endpoint list." do
        id = '[^./?]+'
        map2 = {
          'GET'    => admin_book_show_app,
          'PUT'    => admin_book_update_app,
          'DELETE' => admin_book_delete_app,
        }
        @router.instance_exec(self) do |_|
          _.ok {@variable_endpoints} == [
            [%r'\A/api/books/(#{id})\z',      ['id'], book_show_api, (11..-1)],
            [%r'\A/api/books/(#{id})/edit\z', ['id'], book_edit_api, (11..-6)],
            [%r'\A/api/books/(#{id})/comments\z',          ['book_id'], comment_create_api, (11..-10)],
            [%r'\A/api/books/(#{id})/comments/(#{id})\z', ['book_id', 'comment_id'], comment_update_api, nil],
            [%r'\A/admin/books/(#{id})\z', ['id'], map2, (13..-1)],
          ]
        end
      end

    end


    topic '#lookup()' do

      spec "[!ijqws] returns mapped object and urlpath parameter values when urlpath found." do
        ret = @router.lookup('/api/books/123')
        ok {ret} == [book_show_api, {"id"=>"123"}]
      end

      spec "[!vpdzn] returns nil when urlpath not found." do
        ok {@router.lookup('/api')}        == nil
        ok {@router.lookup('/api/book')}   == nil
        ok {@router.lookup('/api/books/')} == nil
      end

      spec "[!24khb] finds in fixed urlpaths at first." do
        ok {@router.lookup('/')}            == [welcome_app, nil]
        ok {@router.lookup('/api/books')}   == [book_list_api, nil]
        dict = {'GET'=>admin_book_list_app, 'POST'=>admin_book_create_app}
        ok {@router.lookup('/admin/books')} == [dict, nil]
      end

      spec "[!iwyzd] urlpath param value is nil when found in fixed urlpaths." do
        obj, vars = @router.lookup('/')
        ok {vars} == nil
        obj, vars = @router.lookup('/api/books')
        ok {vars} == nil
      end

      spec "[!upacd] finds in variable urlpath cache if it is enabled." do
        mapping = [
          ['/api/books/:id', book_show_api],
        ]
        r = Rack::JetRouter.new(mapping, cache_size: 3)
        pair = r.lookup('/api/books/123')
        ok {pair} == [book_show_api, {"id"=>"123"}]
        r.instance_exec(self) do |_|
          _.ok {@cache_dict} == {'/api/books/123'=>pair}
          #
          @cache_dict['/api/books/999'] = [book_list_api, {"ID"=>"111"}]
        end
        pair = r.lookup('/api/books/999')
        ok {pair} == [book_list_api, {"ID"=>"111"}]
      end

      spec "[!84inr] caches result when variable urlpath cache enabled." do
        mapping = [
          ['/books/:id', book_show_api],
        ]
        r = Rack::JetRouter.new(mapping, cache_size: 3)
        #
        pair1 = r.lookup('/books/1'); ok {pair1} == [book_show_api, {"id"=>"1"}]
        pair2 = r.lookup('/books/2'); ok {pair2} == [book_show_api, {"id"=>"2"}]
        pair3 = r.lookup('/books/3'); ok {pair3} == [book_show_api, {"id"=>"3"}]
        r.instance_exec(self) do |_|
          _.ok {@cache_dict} == {
            '/books/1'=>pair1,
            '/books/2'=>pair2,
            '/books/3'=>pair3,
          }
        end
        #
        pair4 = r.lookup('/books/4'); ok {pair4} == [book_show_api, {"id"=>"4"}]
        r.instance_exec(self) do |_|
          _.ok {@cache_dict} == {
            '/books/2'=>pair2,
            '/books/3'=>pair3,
            '/books/4'=>pair4,
          }
        end
      end

      spec "[!1zx7t] variable urlpath cache is based on LRU." do
        mapping = [
          ['/books/:id', book_show_api],
        ]
        r = Rack::JetRouter.new(mapping, cache_size: 3)
        #
        pair1 = r.lookup('/books/1')
        pair2 = r.lookup('/books/2')
        pair3 = r.lookup('/books/3')
        pair4 = r.lookup('/books/4')
        r.instance_exec(self) do |_|
          _.ok {@cache_dict} == {
            '/books/2'=>pair2,
            '/books/3'=>pair3,
            '/books/4'=>pair4,
          }
        end
        #
        ok {r.lookup('/books/3')} == pair3
        r.instance_exec(self) do |_|
          _.ok {@cache_dict} == {
            '/books/2'=>pair2,
            '/books/4'=>pair4,
            '/books/3'=>pair3,
          }
        end
        #
        ok {r.lookup('/books/1')} == pair1
        r.instance_exec(self) do |_|
          _.ok {@cache_dict} == {
            '/books/4'=>pair4,
            '/books/3'=>pair3,
            '/books/1'=>pair1,
          }
        end
      end

    end


    topic '#call()' do

      spec "[!hse47] invokes app mapped to request urlpath." do
        ok {@router.call(new_env(:GET, '/api/books/123'))}   == [200, {}, ["book_show_api"]]
        ok {@router.call(new_env(:PUT, '/admin/books/123'))} == [200, {}, ["admin_book_update_app"]]
      end

      spec "[!fpw8x] finds mapped app according to env['PATH_INFO']." do
        ok {@router.call(new_env(:GET, '/api/books'))}     == [200, {}, ["book_list_api"]]
        ok {@router.call(new_env(:GET, '/api/books/123'))} == [200, {}, ["book_show_api"]]
      end

      spec "[!wxt2g] guesses correct urlpath and redirects to it automaticaly when request path not found." do
        headers = {"Content-Type"=>"text/plain", "Location"=>"/api/books"}
        content = "Redirect to /api/books"
        ok {@router.call(new_env(:GET, '/api/books/'))}    == [301, headers, [content]]
        #
        headers = {"Content-Type"=>"text/plain", "Location"=>"/api/books/78"}
        content = "Redirect to /api/books/78"
        ok {@router.call(new_env(:GET, '/api/books/78/'))} == [301, headers, [content]]
      end

      spec "[!3vsua] doesn't redict automatically when request path is '/'." do
        r = Rack::JetRouter.new([['/api/books', book_list_api]])
        ok {r.call(new_env(:GET, '/'))} == [404, {"Content-Type"=>"text/plain"}, ["404 Not Found"]]
      end

      spec "[!hyk62] adds QUERY_STRING to redirect location." do
        headers = {"Content-Type"=>"text/plain", "Location"=>"/api/books?x=1&y=2"}
        content = "Redirect to /api/books?x=1&y=2"
        env = new_env(:GET, '/api/books/', {"QUERY_STRING"=>"x=1&y=2"})
        ok {@router.call(env)} == [301, headers, [content]]
      end

      spec "[!30x0k] returns 404 when request urlpath not found." do
        expected = [404, {"Content-Type"=>"text/plain"}, ["404 Not Found"]]
        ok {@router.call(new_env(:GET, '/xxx'))} == expected
        ok {@router.call(new_env(:GET, '/api/book'))} == expected
      end

      case_when "[!gclbs] if mapped object is a Hash..." do

        spec "[!p1fzn] invokes app mapped to request method." do
          ok {@router.call(new_env(:GET,    '/admin/books'))}     == [200, {}, ["admin_book_list_app"]]
          ok {@router.call(new_env(:POST,   '/admin/books'))}     == [200, {}, ["admin_book_create_app"]]
          ok {@router.call(new_env(:GET,    '/admin/books/123'))} == [200, {}, ["admin_book_show_app"]]
          ok {@router.call(new_env(:PUT,    '/admin/books/123'))} == [200, {}, ["admin_book_update_app"]]
          ok {@router.call(new_env(:DELETE, '/admin/books/123'))} == [200, {}, ["admin_book_delete_app"]]
        end

        spec "[!5m64a] returns 405 when request method is not allowed." do
          expected = [405, {"Content-Type"=>"text/plain"}, ["405 Method Not Allowed"]]
          ok {@router.call(new_env(:PUT,    '/admin/books'))} == expected
          ok {@router.call(new_env(:FOOBAR, '/admin/books'))} == expected
        end

        spec "[!ys1e2] uses GET method when HEAD is not mapped." do
          ok {@router.call(new_env(:HEAD,    '/admin/books'))}     == [200, {}, ["admin_book_list_app"]]
          ok {@router.call(new_env(:HEAD,    '/admin/books/123'))} == [200, {}, ["admin_book_show_app"]]
        end

        spec "[!2hx6j] try ANY method when request method is not mapped." do
          mapping = [
            ['/admin/books', {:ANY=>admin_book_list_app}]
          ]
          r = Rack::JetRouter.new(mapping)
          expected = [200, {}, ["admin_book_list_app"]]
          ok {r.call(new_env(:GET,    '/admin/books'))} == expected
          ok {r.call(new_env(:POST,   '/admin/books'))} == expected
          ok {r.call(new_env(:PUT,    '/admin/books'))} == expected
          ok {r.call(new_env(:DELETE, '/admin/books'))} == expected
        end

      end

      spec "[!2c32f] stores urlpath parameter values into env['rack.urlpath_params']." do
        env = new_env(:GET,    '/api/books')
        @router.call(env)
        ok {env['rack.urlpath_params']} == nil
        env = new_env(:GET,    '/api/books/123')
        @router.call(env)
        ok {env['rack.urlpath_params']} == {"id"=>"123"}
        env = new_env(:GET,    '/api/books/123/comments/999')
        @router.call(env)
        ok {env['rack.urlpath_params']} == {"book_id"=>"123", "comment_id"=>"999"}
        #
        env = new_env(:GET,    '/admin/books')
        @router.call(env)
        ok {env['rack.urlpath_params']} == nil
        env = new_env(:GET,    '/admin/books/123')
        @router.call(env)
        ok {env['rack.urlpath_params']} == {"id"=>"123"}
      end

    end


    topic '#each()' do

      spec "[!ep0pw] yields pair of urlpath pattern and app." do
        arr = []
        @router.each do |upath, app|
          arr << [upath, app]
        end
        ok {arr[0]} == ["/", welcome_app]
        ok {arr[1]} == ["/index.html", welcome_app]
        ok {arr[2]} == ["/api/books", book_list_api]
        ok {arr[3]} == ["/api/books/new", book_new_api]
        ok {arr[4]} == ["/api/books/:id", book_show_api]
        ok {arr[5]} == ["/api/books/:id/edit", book_edit_api]
        ok {arr[6]} == ["/api/books/:book_id/comments", comment_create_api]
        ok {arr[7]} == ["/api/books/:book_id/comments/:comment_id", comment_update_api]
        ok {arr[8]} == ["/admin/books", {"GET"=>admin_book_list_app, "POST"=>admin_book_create_app}]
        ok {arr[9]} == ["/admin/books/:id", {"GET"=>admin_book_show_app, "PUT"=>admin_book_update_app, "DELETE"=>admin_book_delete_app}]
      end

    end


    topic '#redirect_to()' do

      spec "[!9z57v] returns 301 and 'Location' header." do
        ret = @router.instance_eval { redirect_to("/foo") }
        headers = {"Content-Type" => "text/plain", "Location" => "/foo"}
        ok {ret} == [301, headers, ["Redirect to /foo"]]
      end

    end


    topic '#store_param_values()' do

      spec "[!94riv] stores urlpath param values into `env['rack.urlpath_params']`." do
        env = {}
        @router.instance_eval { store_param_values(env, {"id"=>123}) }
        ok {env} == {'rack.urlpath_params' => {"id"=>123}}
      end

      spec "[!9he9h] env key can be changed by `env_key:` kwarg of 'JetRouter#initialize()'." do
        router = Rack::JetRouter.new([], env_key: 'rack.params')
        env = {}
        router.instance_eval { store_param_values(env, {"book_id"=>123}) }
        ok {env} == {'rack.params' => {"book_id"=>123}}
      end

    end


    topic '#build_param_values()' do

      case_when "[!qxcis] when 'int_param:' kwarg is specified to constructor..." do

        spec "[!l6p84] converts urlpath pavam value into integer." do
          router = Rack::JetRouter.new([], int_param: /(\A|_)id\z/)
          router.instance_exec(self) do |_|
            ret = build_param_values(["id", "name"], ["123", "foo"])
            _.ok {ret} == {"id" => 123, "name" => "foo"}
          end
        end

      end

      case_when "[!vrbo5] else..." do

        spec "[!yc9n8] creates new Hash object from param names and values." do
          router = Rack::JetRouter.new([])
          router.instance_exec(self) do |_|
            ret = build_param_values(["id", "name"], ["123", "foo"])
            _.ok {ret} == {"id" => "123", "name" => "foo"}
          end
        end

      end

    end


  end


end
