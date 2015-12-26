# -*- coding: utf-8 -*-

###
### $Release: 0.0.0 $
### $Copyright: copyright(c) 2015 kuwata-lab.com all rights reserved $
### $License: MIT License $
###

require_relative '../test_helper'


describe Rack::JetRouter do

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
  #
  jet_router = Rack::JetRouter.new(whole_urlpath_mapping)
  #
  def new_env(req_method, req_path, opts={})
    opts[:method] = req_method.to_s
    env = ::Rack::MockRequest.env_for(req_path, opts)
    return env
  end


  describe '#range_of_urlpath_param()' do

    it "[!syrdh] returns Range object when urlpath_pattern contains just one param." do
      jet_router.instance_exec(self) do |_|
        r1 = range_of_urlpath_param('/books/:id')
        _.ok {r1} == (7..-1)
        _.ok {'/books/123'[r1]} == '123'
        r2 = range_of_urlpath_param('/books/:id.html')
        _.ok {r2} == (7..-6)
        _.ok {'/books/4567.html'[r2]} == '4567'
      end
    end

    it "[!skh4z] returns nil when urlpath_pattern contains more than two params." do
      jet_router.instance_exec(self) do |_|
        _.ok {range_of_urlpath_param('/books/:book_id/comments/:comment_id')} == nil
        _.ok {range_of_urlpath_param('/books/:id(:format)')} == nil
      end
    end

    it "[!acj5b] returns nil when urlpath_pattern contains no params." do
      jet_router.instance_exec(self) do |_|
        _.ok {range_of_urlpath_param('/books')} == nil
      end
    end

  end


  describe '#compile_urlpath_pattern()' do

    it "[!joozm] escapes metachars with backslash in text part." do
      jet_router.instance_exec(self) do |_|
        _.ok {compile_urlpath_pattern('/foo.html')} == ['/foo\.html', nil]
      end
    end

    it "[!rpezs] converts '/books/:id' into '/books/([^./]+)'." do
      jet_router.instance_exec(self) do |_|
        _.ok {compile_urlpath_pattern('/books/:id')} == ['/books/([^./]+)', ['id']]
      end
    end

    it "[!4dcsa] converts '/index(.:format)' into '/index(?:\.([^./]+))?'." do
      jet_router.instance_exec(self) do |_|
        _.ok {compile_urlpath_pattern('/index(.:format)')} == ['/index(?:\.([^./]+))?', ['format']]
      end
    end

    it "[!1d5ya] rethrns compiled string and nil when no urlpath parameters nor parens." do
      jet_router.instance_exec(self) do |_|
        _.ok {compile_urlpath_pattern('/index')} == ['/index', nil]
      end
    end

    it "[!of1zq] returns compiled string and urlpath param names when urlpath param or parens exist." do
      jet_router.instance_exec(self) do |_|
        _.ok {compile_urlpath_pattern('/books/:id')} == ['/books/([^./]+)', ['id']]
        _.ok {compile_urlpath_pattern('/books/:id(.:format)')} == ['/books/([^./]+)(?:\.([^./]+))?', ['id', 'format']]
        _.ok {compile_urlpath_pattern('/index(.html)')} == ['/index(?:\.html)?', []]
      end
    end

  end


  describe '#compile_mapping()' do

    it "[!xzo7k] returns regexp, hash, and array." do
      mapping = [
        ['/',              welcome_app],
        ['/books/:id'    , book_show_api],
      ]
      expected = '
          \A
              /books/[^./]+(\z)
          \z
      '.gsub(/\s+/, '')
      jet_router.instance_exec(self) do |_|
        rexp, dict, list = compile_mapping(mapping)
        _.ok {rexp} == Regexp.new(expected)
        _.ok {dict} == {
          '/'                => welcome_app,
        }
        _.ok {list} == [
          [%r'\A/books/([^./]+)\z',      ['id'], book_show_api, (7..-1)],
        ]
      end
    end

    it "[!gfxgr] deletes unnecessary grouping." do
      mapping = [
        ['/'               , welcome_app],
        ['/api/books'      , book_list_api],
      ]
      expected = '
          \A
          \z
      '.gsub(/\s+/, '')
      jet_router.instance_exec(self) do |_|
        rexp, dict, list = compile_mapping(mapping)
        _.ok {rexp} == Regexp.new(expected)
        _.ok {dict} == {
          '/'                => welcome_app,
          '/api/books'       => book_list_api,
        }
        _.ok {list} == [
        ]
      end
    end

    it "[!pv2au] deletes unnecessary urlpath regexp." do
      mapping = [
        ['/'               , welcome_app],
        ['/api', [
          ['/books', [
            [''            , book_list_api],
            ['/new'        , book_new_api],
          ]],
          ['/books2', [
            ['/:id'        , book_show_api],
          ]],
        ]],
      ]
      expected = '
          \A
          (?:
              /api
                  (?:
                      /books2
                          /[^./]+(\z)
                  )
          )
          \z
      '.gsub(/\s+/, '')
      jet_router.instance_exec(self) do |_|
        rexp, dict, list = compile_mapping(mapping)
        _.ok {rexp} == Regexp.new(expected)
        _.ok {dict} == {
          '/'                => welcome_app,
          '/api/books'       => book_list_api,
          '/api/books/new'   => book_new_api,
        }
        _.ok {list} == [
          [%r'\A/api/books2/([^./]+)\z',  ['id'], book_show_api, (12..-1)],
        ]
      end
    end

    it "[!bh9lo] deletes unnecessary grouping which contains only an element." do
      mapping = [
        ['/api', [
          ['/books', [
            ['/:id'        , book_show_api],
          ]],
        ]],
      ]
      expected = '
          \A
          (?:
              /api
                  (?:
                      /books
                          /[^./]+(\z)
                  )
          )
          \z
      '.gsub(/\s+/, '')
      jet_router.instance_exec(self) do |_|
        rexp, dict, list = compile_mapping(mapping)
        _.ok {rexp} == Regexp.new(expected)
        _.ok {dict} == {}
        _.ok {list} == [
          [%r'\A/api/books/([^./]+)\z',  ['id'], book_show_api, (11..-1)],
        ]
      end
    end

    it "[!l63vu] handles urlpath pattern as fixed when no urlpath params." do
      mapping = [
        ['/api/books'      , book_list_api],
      ]
      expected = '
          \A
          \z
      '.gsub(/\s+/, '')
      jet_router.instance_exec(self) do |_|
        rexp, dict, list = compile_mapping(mapping)
        _.ok {rexp} == Regexp.new(expected)
        _.ok {dict} == {
          '/api/books'       => book_list_api,
        }
        _.ok {list} == [
        ]
      end
    end

    it "[!vfytw] handles urlpath pattern as variable when urlpath param exists." do
      mapping = [
        ['/api/books/:id'  , book_show_api],
      ]
      expected = '
          \A
              /api/books/[^./]+(\z)
          \z
      '.gsub(/\s+/, '')
      jet_router.instance_exec(self) do |_|
        rexp, dict, list = compile_mapping(mapping)
        _.ok {rexp} == Regexp.new(expected)
        _.ok {dict} == {
        }
        _.ok {list} == [
          [%r'\A/api/books/([^./]+)\z',  ['id'], book_show_api, (11..-1)],
        ]
      end
    end

    it "[!2ktpf] handles end-point." do
      mapping = [
        ['/'               , welcome_app],
        ['/api/books'      , book_list_api],
        ['/api/books/:id'  , book_show_api],
      ]
      expected = '
          \A
              /api/books/[^./]+(\z)
          \z
      '.gsub(/\s+/, '')
      jet_router.instance_exec(self) do |_|
        rexp, dict, list = compile_mapping(mapping)
        _.ok {rexp} == Regexp.new(expected)
        _.ok {dict} == {
          '/'                => welcome_app,
          '/api/books'       => book_list_api,
        }
        _.ok {list} == [
          [%r'\A/api/books/([^./]+)\z',  ['id'], book_show_api, (11..-1)],
        ]
      end
    end

    it "[!ospaf] accepts nested mapping." do
      mapping = [
        ['/admin', [
          ['/api', [
            ['/books', [
              ['',           book_list_api],
              ['/:id',       book_show_api],
            ]],
          ]],
        ]],
      ]
      expected = '
          \A
          (?:
              /admin
                  (?:
                      /api
                          (?:
                              /books
                                  /[^./]+(\z)
                          )
                  )
          )
          \z
      '.gsub(/\s+/, '')
      jet_router.instance_exec(self) do |_|
        rexp, dict, list = compile_mapping(mapping)
        _.ok {rexp} == Regexp.new(expected)
        _.ok {dict} == {
          '/admin/api/books'       => book_list_api,
        }
        _.ok {list} == [
          [%r'\A/admin/api/books/([^./]+)\z',  ['id'], book_show_api, (17..-1)],
        ]
      end
    end

    describe "[!guhdc] if mapping dict is specified..." do

      it "[!r7cmk] converts keys into string." do
        mapping = [
          ['/books', {:GET=>book_list_api, :POST=>book_create_api}]
        ]
        Rack::JetRouter.new([]).instance_exec(self) do |_|
          rexp, dict, list = compile_mapping(mapping)
          _.ok {dict['/books']} == {'GET'=>book_list_api, 'POST'=>book_create_api}
        end
      end

      it "[!z9kww] allows 'ANY' as request method." do
        mapping = [
          ['/books', {'ANY'=>book_list_api, 'POST'=>book_create_api}]
        ]
        Rack::JetRouter.new([]).instance_exec(self) do |_|
          rexp, dict, list = compile_mapping(mapping)
          _.ok {dict['/books']} == {'ANY'=>book_list_api, 'POST'=>book_create_api}
        end
      end

      it "[!k7sme] raises error when unknown request method specified." do
        mapping = [
          ['/books', {"UNLOCK"=>book_list_api}]
        ]
        Rack::JetRouter.new([]).instance_exec(self) do |_|
          pr = proc { compile_mapping(mapping) }
          _.ok {pr}.raise?(ArgumentError, '"UNLOCK": unknown request method.')
        end
      end

    end

  end


  describe '#error_not_found()' do

    it "[!mlruv] returns 404 response." do
      expected = [404, {"Content-Type"=>"text/plain"}, ["404 Not Found"]]
      env = new_env('GET', '/xxx')
      jet_router.instance_exec(self) do |_|
        _.ok {error_not_found(env)} == expected
      end
    end

  end


  describe '#error_not_allowed()' do

    it "[!mjigf] returns 405 response." do
      expected = [405, {"Content-Type"=>"text/plain"}, ["405 Method Not Allowed"]]
      env = new_env('POST', '/')
      jet_router.instance_exec(self) do |_|
        _.ok {error_not_allowed(env)} == expected
      end
    end

  end


  describe '#initialize()' do

    it "[!u2ff4] compiles urlpath mapping." do
      jet_router.instance_exec(self) do |_|
        expected = '
            \A
            (?:
                /api
                    (?:
                        /books
                            (?:/[^./]+(\z)|/[^./]+/edit(\z))
                    |
                        /books/[^./]+/comments
                            (?:(\z)|/[^./]+(\z))
                    )
            |
                /admin
                    (?:/books
                        /[^./]+(\z)
                    )
            )
            \z
        '.gsub(/\s+/, '')
        _.ok {@urlpath_rexp} == Regexp.new(expected)
        _.ok {@fixed_urlpath_dict} == {
          '/'                => welcome_app,
          '/index.html'      => welcome_app,
          '/api/books'       => book_list_api,
          '/api/books/new'   => book_new_api,
          '/admin/books'     => {
            'GET'=>admin_book_list_app,
            'POST'=>admin_book_create_app,
          },
        }
        _.ok {@variable_urlpath_list} == [
          [%r'\A/api/books/([^./]+)\z',      ['id'], book_show_api, (11..-1)],
          [%r'\A/api/books/([^./]+)/edit\z', ['id'], book_edit_api, (11..-6)],
          [%r'\A/api/books/([^./]+)/comments\z',          ['book_id'], comment_create_api, (11..-10)],
          [%r'\A/api/books/([^./]+)/comments/([^./]+)\z', ['book_id', 'comment_id'], comment_update_api, nil],
          [%r'\A/admin/books/([^./]+)\z',    ['id'], {'GET'    => admin_book_show_app,
                                                      'PUT'    => admin_book_update_app,
                                                      'DELETE' => admin_book_delete_app}, (13..-1)],
        ]
      end
    end

  end


  describe '#find()' do

    it "[!ijqws] returns mapped object and urlpath parameter values when urlpath found." do
      ret = jet_router.find('/api/books/123')
      ok {ret} == [book_show_api, {"id"=>"123"}]
    end

    it "[!vpdzn] returns nil when urlpath not found." do
      ok {jet_router.find('/api')}        == nil
      ok {jet_router.find('/api/book')}   == nil
      ok {jet_router.find('/api/books/')} == nil
    end

    it "[!24khb] finds in fixed urlpaths at first." do
      ok {jet_router.find('/')}            == [welcome_app, nil]
      ok {jet_router.find('/api/books')}   == [book_list_api, nil]
      dict = {'GET'=>admin_book_list_app, 'POST'=>admin_book_create_app}
      ok {jet_router.find('/admin/books')} == [dict, nil]
    end

    it "[!iwyzd] urlpath param value is nil when found in fixed urlpaths." do
      obj, vars = jet_router.find('/')
      ok {vars} == nil
      obj, vars = jet_router.find('/api/books')
      ok {vars} == nil
    end

    it "[!upacd] finds in variable urlpath cache if it is enabled." do
      mapping = [
        ['/api/books/:id', book_show_api],
      ]
      r = Rack::JetRouter.new(mapping, urlpath_cache_size: 3)
      pair = r.find('/api/books/123')
      ok {pair} == [book_show_api, {"id"=>"123"}]
      r.instance_exec(self) do |_|
        _.ok {@variable_urlpath_cache} == {'/api/books/123'=>pair}
        #
        @variable_urlpath_cache['/api/books/999'] = [book_list_api, {"ID"=>"111"}]
      end
      pair = r.find('/api/books/999')
      ok {pair} == [book_list_api, {"ID"=>"111"}]
    end

    it "[!84inr] caches result when variable urlpath cache enabled." do
      mapping = [
        ['/books/:id', book_show_api],
      ]
      r = Rack::JetRouter.new(mapping, urlpath_cache_size: 3)
      #
      pair1 = r.find('/books/1'); ok {pair1} == [book_show_api, {"id"=>"1"}]
      pair2 = r.find('/books/2'); ok {pair2} == [book_show_api, {"id"=>"2"}]
      pair3 = r.find('/books/3'); ok {pair3} == [book_show_api, {"id"=>"3"}]
      r.instance_exec(self) do |_|
        _.ok {@variable_urlpath_cache} == {
          '/books/1'=>pair1,
          '/books/2'=>pair2,
          '/books/3'=>pair3,
        }
      end
      #
      pair4 = r.find('/books/4'); ok {pair4} == [book_show_api, {"id"=>"4"}]
      r.instance_exec(self) do |_|
        _.ok {@variable_urlpath_cache} == {
          '/books/2'=>pair2,
          '/books/3'=>pair3,
          '/books/4'=>pair4,
        }
      end
    end

    it "[!1zx7t] variable urlpath cache is based on LRU." do
      mapping = [
        ['/books/:id', book_show_api],
      ]
      r = Rack::JetRouter.new(mapping, urlpath_cache_size: 3)
      #
      pair1 = r.find('/books/1')
      pair2 = r.find('/books/2')
      pair3 = r.find('/books/3')
      pair4 = r.find('/books/4')
      r.instance_exec(self) do |_|
        _.ok {@variable_urlpath_cache} == {
          '/books/2'=>pair2,
          '/books/3'=>pair3,
          '/books/4'=>pair4,
        }
      end
      #
      ok {r.find('/books/3')} == pair3
      r.instance_exec(self) do |_|
        _.ok {@variable_urlpath_cache} == {
          '/books/2'=>pair2,
          '/books/4'=>pair4,
          '/books/3'=>pair3,
        }
      end
      #
      ok {r.find('/books/1')} == pair1
      r.instance_exec(self) do |_|
        _.ok {@variable_urlpath_cache} == {
          '/books/4'=>pair4,
          '/books/3'=>pair3,
          '/books/1'=>pair1,
        }
      end
    end

  end


  describe '#call()' do

    it "[!hse47] invokes app mapped to request urlpath." do
      ok {jet_router.call(new_env(:GET, '/api/books/123'))}   == [200, {}, ["book_show_api"]]
      ok {jet_router.call(new_env(:PUT, '/admin/books/123'))} == [200, {}, ["admin_book_update_app"]]
    end

    it "[!fpw8x] finds mapped app according to env['PATH_INFO']." do
      ok {jet_router.call(new_env(:GET, '/api/books'))}     == [200, {}, ["book_list_api"]]
      ok {jet_router.call(new_env(:GET, '/api/books/123'))} == [200, {}, ["book_show_api"]]
    end

    it "[!wxt2g] guesses correct urlpath and redirects to it automaticaly when request path not found." do
      headers = {"Content-Type"=>"text/plain", "Location"=>"/api/books"}
      content = "Redirect to /api/books"
      ok {jet_router.call(new_env(:GET, '/api/books/'))}    == [301, headers, [content]]
      #
      headers = {"Content-Type"=>"text/plain", "Location"=>"/api/books/78"}
      content = "Redirect to /api/books/78"
      ok {jet_router.call(new_env(:GET, '/api/books/78/'))} == [301, headers, [content]]
    end

    it "[!3vsua] doesn't redict automatically when request path is '/'." do
      r = Rack::JetRouter.new([['/api/books', book_list_api]])
      ok {r.call(new_env(:GET, '/'))} == [404, {"Content-Type"=>"text/plain"}, ["404 Not Found"]]
    end

    it "[!30x0k] returns 404 when request urlpath not found." do
      expected = [404, {"Content-Type"=>"text/plain"}, ["404 Not Found"]]
      ok {jet_router.call(new_env(:GET, '/xxx'))} == expected
      ok {jet_router.call(new_env(:GET, '/api/book'))} == expected
    end

    describe "[!gclbs] if mapped object is a Hash..." do

      it "[!p1fzn] invokes app mapped to request method." do
        ok {jet_router.call(new_env(:GET,    '/admin/books'))}     == [200, {}, ["admin_book_list_app"]]
        ok {jet_router.call(new_env(:POST,   '/admin/books'))}     == [200, {}, ["admin_book_create_app"]]
        ok {jet_router.call(new_env(:GET,    '/admin/books/123'))} == [200, {}, ["admin_book_show_app"]]
        ok {jet_router.call(new_env(:PUT,    '/admin/books/123'))} == [200, {}, ["admin_book_update_app"]]
        ok {jet_router.call(new_env(:DELETE, '/admin/books/123'))} == [200, {}, ["admin_book_delete_app"]]
      end

      it "[!5m64a] returns 405 when request method is not allowed." do
        expected = [405, {"Content-Type"=>"text/plain"}, ["405 Method Not Allowed"]]
        ok {jet_router.call(new_env(:PUT,    '/admin/books'))} == expected
        ok {jet_router.call(new_env(:FOOBAR, '/admin/books'))} == expected
      end

      it "[!ys1e2] uses GET method when HEAD is not mapped." do
        ok {jet_router.call(new_env(:HEAD,    '/admin/books'))}     == [200, {}, ["admin_book_list_app"]]
        ok {jet_router.call(new_env(:HEAD,    '/admin/books/123'))} == [200, {}, ["admin_book_show_app"]]
      end

      it "[!2hx6j] try ANY method when request method is not mapped." do
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

    it "[!2c32f] stores urlpath parameters as env['rack.urlpath_params']." do
      env = new_env(:GET,    '/api/books')
      jet_router.call(env)
      ok {env['rack.urlpath_params']} == nil
      env = new_env(:GET,    '/api/books/123')
      jet_router.call(env)
      ok {env['rack.urlpath_params']} == {"id"=>"123"}
      env = new_env(:GET,    '/api/books/123/comments/999')
      jet_router.call(env)
      ok {env['rack.urlpath_params']} == {"book_id"=>"123", "comment_id"=>"999"}
      #
      env = new_env(:GET,    '/admin/books')
      jet_router.call(env)
      ok {env['rack.urlpath_params']} == nil
      env = new_env(:GET,    '/admin/books/123')
      jet_router.call(env)
      ok {env['rack.urlpath_params']} == {"id"=>"123"}
    end

  end


  describe 'REQUEST_METHODS' do

    it "[!haggu] contains available request methods." do
      Rack::JetRouter::REQUEST_METHODS.each do |k, v|
        ok {k}.is_a?(String)
        ok {v}.is_a?(Symbol)
        ok {v.to_s} == k
      end
    end

  end


end
