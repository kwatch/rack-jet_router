# -*- coding: utf-8 -*-

###
### $Release: 0.0.0 $
### $Copyright: copyright(c) 2015 kuwata-lab.com all rights reserved $
### $License: MIT License $
###

require_relative './shared'


Oktest.scope do


class Map < Hash
end

def Map(**kwargs)
  return Map.new.update(kwargs)
end


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
  #
  jet_router = Rack::JetRouter.new(whole_urlpath_mapping)
  #
  def new_env(req_method, req_path, opts={})
    opts[:method] = req_method.to_s
    env = ::Rack::MockRequest.env_for(req_path, opts)
    return env
  end

  def _find(d, k)
    return d.key?(k) ? d[k] : _find(d.to_a[0][1], k)
  end

  before do
    @router = Rack::JetRouter.new([])
  end


  topic '#_build_nested_dict()' do

    spec "[!6oa05] builds nested hash object from mapping data." do
      mapping = [
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
      ]
      dict = @router.instance_eval { _build_nested_dict(mapping) }
      id = '[^./?]+'
      ok {dict} == {
        "/api/books/" => {
          :'[^./?]+' => {
            nil => [/\A\/api\/books\/(#{id})\z/,
                    ["id"], book_show_api, 11..-1],
            "/" => {
              "edit" => {
                nil => [/\A\/api\/books\/(#{id})\/edit\z/,
                        ["id"], book_edit_api, 11..-6],
              },
              "comments" => {
                nil => [/\A\/api\/books\/(#{id})\/comments\z/,
                        ["book_id"], comment_create_api, 11..-10],
                "/" => {
                  :'[^./?]+' => {
                    nil => [/\A\/api\/books\/(#{id})\/comments\/(#{id})\z/,
                            ["book_id", "comment_id"], comment_update_api, nil],
                  },
                },
              },
            },
          },
        },
      }
    end

    spec "[!j0pes] if item is a hash object, converts keys from symbol to string." do
      mapping = [
        ['/api'           , [
          ['/books'       , [
            ['/new'       , {GET: book_new_api}],
            ['/:id'       , {GET: book_show_api, DELETE: book_delete_api}],
          ]],
        ]],
      ]
      actuals = []
      dict = @router.instance_eval {
        _build_nested_dict(mapping) {|path, item, _| actuals << [path, item] }
      }
      ok {actuals} == [
        ["/api/books/new", {"GET"=>book_new_api}],
        ["/api/books/:id", {"GET"=>book_show_api, "DELETE"=>book_delete_api}],
      ]
      id = '[^./?]+'
      #expected_map = {:GET=>book_show_api, :DELETE=>book_delete_api}
      expected_map = {"GET"=>book_show_api, "DELETE"=>book_delete_api}
      ok {dict} == {
        "/api/books/" => {
          :"[^./?]+"=> {
            nil => [/\A\/api\/books\/(#{id})\z/,
                    ["id"], expected_map, (11..-1)],
          },
        },
      }
    end

    spec "[!vfytw] handles urlpath pattern as variable when urlpath param exists." do
      mapping = [
        ['/api', [
          ['/books', [
            ['/new'       , {GET: book_new_api}],
            ['/:id'       , {GET: book_show_api}],
          ]],
        ]],
      ]
      actuals = []
      @router.instance_eval {
        _build_nested_dict(mapping) {|path, _, fixed_p| actuals << [path, fixed_p] }
      }
      id = '[^./?]+'
      ok {actuals} == [
        ["/api/books/new", true],
        ["/api/books/:id", false],
      ]
    end

    spec "[!uyupj] handles urlpath parameter such as ':id'." do
      mapping = [
        ['/api', [
          ['/books/:book_id/comments', [
            [''           , {POST: comment_create_api}],
            ['/:id'       , {PUT: comment_update_api}],
          ]],
        ]],
      ]
      dict = @router.instance_eval { _build_nested_dict(mapping) }
      id = '[^./?]+'
      ok {dict} == {
        "/api/books/" => {
          :"[^./?]+" => {
            "/comments" => {
              nil => [%r`\A/api/books/(#{id})/comments\z`,
                      ["book_id"], {"POST"=>comment_create_api}, (11..-10)],
              "/" => {
                :"[^./?]+" => {
                  nil => [%r`\A/api/books/(#{id})/comments/(#{id})\z`,
                          ["book_id", "id"], {"PUT"=>comment_update_api}, nil],
                },
              },
            },
          },
        },
      }
    end

    spec "[!j9cdy] handles optional urlpath parameter such as '(.:format)'." do
      mapping = [
        ['/api', [
          ['/books', [
            ['(.:format)'           , {GET: book_list_api}],
            ['/:id(.:format)'       , {GET: book_show_api}],
          ]],
        ]],
      ]
      actuals = []
      dict = @router.instance_eval {
        _build_nested_dict(mapping) do |path, item, fixed_p|
          actuals << [path, item, fixed_p]
        end
      }
      id = '[^./?]+'
      ok {dict} == {
        "/api/books" => {
          :"(?:\\.[^./?]+)?" => {
            nil => [%r`\A/api/books(?:\.(#{id}))?\z`,
                    ["format"], {"GET"=>book_list_api}, (10..-1)]},
          "/" => {
            :"[^./?]+" => {
              :"(?:\\.[^./?]+)?" => {
                nil => [%r`\A/api/books/(#{id})(?:\.(#{id}))?\z`,
                        ["id", "format"], {"GET"=>book_show_api}, nil],
              },
            },
          },
        },
      }
    end

    spec "[!akkkx] converts urlpath param into regexp." do
      mapping = [
        ["/api/books/:id", book_show_api],
      ]
      dict = @router.instance_eval { _build_nested_dict(mapping) }
      tuple = _find(dict, nil)
      id = '[^./?]+'
      ok {tuple[0]} == %r`\A/api/books/(#{id})\z`
    end

    spec "[!po6o6] param regexp should be stored into nested dict as a Symbol." do
      mapping = [
        ["/api/books/:id", book_show_api],
      ]
      dict = @router.instance_eval { _build_nested_dict(mapping) }
      ok {dict["/api/books/"].keys()} == [:'[^./?]+']
    end

    spec "[!zoym3] urlpath string should be escaped." do
      mapping = [
        ["/api/books.dir.tmp/:id.tar.gz", book_show_api],
      ]
      dict = @router.instance_eval { _build_nested_dict(mapping) }
      tuple = _find(dict, nil)
      id = '[^./?]+'
      ok {tuple[0]} == %r`\A/api/books\.dir\.tmp/(#{id})\.tar\.gz\z`
    end

    spec "[!o642c] remained string after param should be handled correctly." do
      mapping = [
        ["/api/books", [
          ["/:id(.:format)(.gz)", book_show_api],
        ]],
      ]
      dict = @router.instance_eval { _build_nested_dict(mapping) }
      tuple = _find(dict, nil)
      id = '[^./?]+'
      ok {tuple[0]} == %r`\A/api/books/(#{id})(?:\.(#{id}))?(?:\.gz)?\z`
    end

    spec "[!kz8m7] range object should be included into tuple if only one param exist." do
      mapping = [
        ["/api/books/:id.json", book_show_api],
      ]
      dict = @router.instance_eval { _build_nested_dict(mapping) }
      tuple = _find(dict, nil)
      id = '[^./?]+'
      ok {tuple} == [%r`\A/api/books/(#{id})\.json\z`,
                     ["id"], book_show_api, (11..-6)]
    end

    spec "[!c6xmp] tuple should be stored into nested dict with key 'nil'." do
      mapping = [
        ["/api/books/:id.json", book_show_api],
      ]
      dict = @router.instance_eval { _build_nested_dict(mapping) }
      id = '[^./?]+'
      ok {dict} == {
        "/api/books/" => {
          :"[^./?]+" => {
            ".json" => {
              nil => [%r`\A/api/books/(#{id})\.json\z`,
                      ["id"], book_show_api, (11..-6)],
            },
          },
        },
      }
    end

    spec "[!gls5k] yields callback if given." do
      mapping = [
        ['/api', [
          ['/books', [
            ['/new'       , book_new_api],
            ['/:id'       , book_show_api],
          ]],
        ]],
      ]
      actuals = []
      @router.instance_eval {
        _build_nested_dict(mapping) {|*args| actuals << args }
      }
      id = '[^./?]+'
      ok {actuals} == [
        ["/api/books/new", book_new_api , true],
        ["/api/books/:id", book_show_api, false],
      ]
    end

  end


  topic '#_traverse_mapping()' do

    spec "[!9s3f0] supports both nested list mapping and nested dict mapping." do
      expected = [
        ["/api/books"    , book_list_api],
        ["/api/books/new", book_new_api ],
        ["/api/books/:id", book_show_api],
      ]
      #
      mapping1 = [
        ['/api' , [
          ['/books' , [
            [''           , book_list_api],
            ['/new'       , book_new_api],
            ['/:id'       , book_show_api],
          ]],
        ]],
      ]
      actuals1 = []
      @router.instance_eval do
        _traverse_mapping(mapping1, "", mapping1.class) {|*args| actuals1 << args }
      end
      ok {actuals1} == expected
      #
      mapping2 = {
        '/api' => {
          '/books' => {
            ''      => book_list_api,
            '/new'  => book_new_api,
            '/:id'  => book_show_api,
          },
        },
      }
      actuals2 = []
      @router.instance_eval do
        _traverse_mapping(mapping2, "", mapping2.class) {|*args| actuals2 << args }
      end
      ok {actuals2} == expected
    end

    spec "[!2ntnk] nested dict mapping can have subclass of Hash as handlers." do
      ok {Map(GET: 1)}.is_a?(Map)
      ok {Map(GET: 1)}.is_a?(Hash)
      ok {Map} < Hash
      #
      mapping = {
        '/api' => {
          '/books' => {
            ''      => Map(GET: book_list_api),
            '/new'  => Map(GET: book_new_api),
            '/:id'  => Map(GET: book_show_api, PUT: book_edit_api),
          },
        },
      }
      actuals = []
      @router.instance_eval do
        _traverse_mapping(mapping, "", mapping.class) {|*args| actuals << args }
      end
      ok {actuals} == [
        ["/api/books"    , Map(GET: book_list_api)],
        ["/api/books/new", Map(GET: book_new_api) ],
        ["/api/books/:id", Map(GET: book_show_api, PUT: book_edit_api)],
      ]
    end

    spec "[!dj0sh] traverses mapping recursively." do
      mapping = [
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
      ]
      actuals = []
      @router.instance_eval do
        _traverse_mapping(mapping, "", mapping.class) {|*args| actuals << args }
      end
      ok {actuals} ==  [
        ["/api/books"         , book_list_api],
        ["/api/books/new"     , book_new_api],
        ["/api/books/:id"     , book_show_api],
        ["/api/books/:id/edit", book_edit_api],
        ["/api/books/:book_id/comments"            , comment_create_api],
        ["/api/books/:book_id/comments/:comment_id", comment_update_api],
      ]
    end

    spec "[!brhcs] yields block for each full path and handler." do
      mapping = {
        '/api' => {
          '/books' => {
            ''          => book_list_api,
            '/new'      => book_new_api,
            '/:id'      => book_show_api,
            '/:id/edit' => book_edit_api,
          },
          '/books/:book_id/comments' => {
            ''             => comment_create_api,
            '/:comment_id' => comment_update_api,
          },
        },
      }
      actuals = []
      @router.instance_eval do
        _traverse_mapping(mapping, "", mapping.class) {|*args| actuals << args }
      end
      ok {actuals} ==  [
        ["/api/books"         , book_list_api],
        ["/api/books/new"     , book_new_api],
        ["/api/books/:id"     , book_show_api],
        ["/api/books/:id/edit", book_edit_api],
        ["/api/books/:book_id/comments"            , comment_create_api],
        ["/api/books/:book_id/comments/:comment_id", comment_update_api],
      ]
    end
  end


  topic '#_next_dict()' do

    case_when "[!s1rzs] if new key exists in dict..." do

      spec "[!io47b] just returns corresponding value and not change dict." do
        dict = {"a" => {"b" => 10}}
        d2 = @router.instance_eval { _next_dict(dict, "a") }
        ok {d2} == {"b" => 10}
        ok {dict} == {"a" => {"b" => 10}}
      end

    end

    spec "[!3ndpz] returns next dict." do
      dict = {"aa1" => {"aa2"=>10}}
      d2 = @router.instance_eval { _next_dict(dict, "aa8") }
      ok {d2} == {}
      ok {dict} == {"aa" => {"1" => {"aa2"=>10}, "8" => {}}}
      ok {dict["aa"]["8"]}.same?(d2)
    end

    spec "[!5fh08] keeps order of keys in dict." do
      dict = {"aa1" => {"aa2"=>10}, "bb1" => {"bb2"=>20}, "cc1" => {"cc2"=>30}}
      d2 = @router.instance_eval { _next_dict(dict, "bb8") }
      ok {d2} == {}
      ok {dict} == {
        "aa1" => {"aa2"=>10},
        "bb"  => {"1" => {"bb2"=>20}, "8"=>{}},
        "cc1" => {"cc2"=>30},
      }
      ok {dict["bb"]["8"]}.same?(d2)
      ok {dict.keys} == ["aa1", "bb", "cc1"]
    end

    spec "[!4wdi7] ignores Symbol key (which represents regexp)." do
      dict = {"aa1" => {"aa2"=>10}, :"bb1" => {"bb2"=>20}}
      d2 = @router.instance_eval { _next_dict(dict, "bb1") }
      ok {d2} == {}
      ok {dict} == {
        "aa1" => {"aa2"=>10},
        :"bb1" => {"bb2"=>20},
        "bb1" => {},
      }
      ok {dict["bb1"]}.same?(d2)
    end

    spec "[!66sdb] ignores nil key (which represents leaf node)." do
      dict = {"aa1" => {"aa2" => 10}, nil => ["foo"]}
      d2 = @router.instance_eval { _next_dict(dict, "mm1") }
      ok {d2} == {}
      ok {dict} == {"aa1" => {"aa2" => 10}, nil => ["foo"], "mm1" => {}}
      ok {dict["mm1"]}.same?(d2)
    end

    case_when "[!46o9b] if existing key is same as common prefix..." do

      spec "[!4ypls] not replace existing key." do
        dict = {"aa1" => {"aa2" => 10}, "bb1" => {"bb2" => 20}}
        aa1 = dict["aa1"]
        d2 = @router.instance_eval { _next_dict(dict, "aa1mm2") }
        ok {d2} == {}
        ok {dict} == {
          "aa1" => {"aa2" => 10, "mm2" => d2},
          "bb1" => {"bb2" => 20},
        }
        ok {dict["aa1"]}.same?(aa1)
      end

    end

    case_when "[!veq0q] if new key is same as common prefix..." do

      spec "[!0tboh] replaces existing key with ney key." do
        dict = {"aa1" => {"aa2" => 10}, "bb1" => {"bb2" => 20}}
        aa1 = dict["aa1"]
        d2 = @router.instance_eval { _next_dict(dict, "aa") }
        ok {d2} == {"1" => {"aa2" => 10}}
        ok {dict} == {
          "aa" => {"1" => {"aa2" => 10}},
          "bb1" => {"bb2" => 20},
        }
        ok {dict["aa"]["1"]}.same?(aa1)
      end

    end

    case_when "[!esszs] if common prefix is a part of exsting key and new key..." do

      spec "[!pesq0] replaces existing key with common prefix." do
        dict = {"aa1" => {"aa2"=>10}, "bb1" => {"bb2"=>20}, "cc1" => {"cc2"=>30}}
        bb1 = dict["bb1"]
        d2 = @router.instance_eval { _next_dict(dict, "bb7") }
        ok {d2} == {}
        ok {dict} == {
          "aa1" => {"aa2"=>10},
          "bb"  => {"1" => {"bb2"=>20}, "7" => {}},
          "cc1" => {"cc2"=>30},
        }
        ok {dict["bb"]["7"]}.same?(d2)
      end

    end

    case_when "[!viovl] if new key has no common prefix with existing keys..." do

      spec "[!i6smv] adds empty dict with new key." do
        dict = {"aa1" => {"aa2"=>10}, "bb1" => {"bb2"=>20}, "cc1" => {"cc2"=>30}}
        d2 = @router.instance_eval { _next_dict(dict, "mm1") }
        ok {dict} == {
          "aa1" => {"aa2"=>10},
          "bb1" => {"bb2"=>20},
          "cc1" => {"cc2"=>30},
          "mm1" => {},
        }
        ok {dict["mm1"]}.same?(d2)
      end

    end

  end


  topic '#_common_prefix()' do

    spec "[!1z2ii] returns common prefix and rest of strings." do
      t = @router.instance_eval { _common_prefix("baar", "bazz") }
      prefix, rest1, rest2 = t
      ok {prefix} == "ba"
      ok {rest1}  == "ar"
      ok {rest2}  == "zz"
    end

    spec "[!86tsd] calculates common prefix of two strings." do
      t = @router.instance_eval { _common_prefix("bar", "barkuz") }
      prefix, rest1, rest2 = t
      ok {prefix} == "bar"
      ok {rest1}  == ""
      ok {rest2}  == "kuz"
      #
      t = @router.instance_eval { _common_prefix("barrab", "bar") }
      prefix, rest1, rest2 = t
      ok {prefix} == "bar"
      ok {rest1}  == "rab"
      ok {rest2}  == ""
    end

  end


  topic '#_param_patterns()' do

    spec "[!j90mw] returns '[^./?]+' and '([^./?]+)' if param specified." do
      x = nil
      s1, s2 = @router.instance_eval { _param_patterns("id", nil) {|a| x = a } }
      ok {s1} == '[^./?]+'
      ok {s2} == '([^./?]+)'
      ok {x} == "id"
    end

    spec "[!raic7] returns '(?:\.[^./?]+)?' and '(?:\.([^./?]+))?' if optional param is '(.:format)'." do
      x = nil
      s1, s2 = @router.instance_eval { _param_patterns(nil, ".:format") {|a| x = a } }
      ok {s1} == '(?:\.[^./?]+)?'
      ok {s2} == '(?:\.([^./?]+))?'
      ok {x} == "format"
    end

    spec "[!69yj9] optional string can contains other params." do
      arr = []
      s1, s2 = @router.instance_eval { _param_patterns(nil, ":yr-:mo-:dy") {|a| arr << a } }
      ok {s1} == '(?:[^./?]+\-[^./?]+\-[^./?]+)?'
      ok {s2} == '(?:([^./?]+)\-([^./?]+)\-([^./?]+))?'
      ok {arr} == ["yr", "mo", "dy"]
    end

  end


  topic '#param_pattern()' do

    spec "[!6sd9b] converts regexp string according to param name." do
      s = @router.instance_eval { param_pattern("id") }
      ok {s} == '[^./?]+'
      s = @router.instance_eval { param_pattern("user_id") }
      ok {s} == '[^./?]+'
      s = @router.instance_eval { param_pattern("username") }
      ok {s} == '[^./?]+'
    end

  end


  topic '#_build_rexp()' do

    spec "[!65yw6] converts nested dict into regexp." do
      dict = {
        "/api/books/" => {
          :"[^./?]+" => {
            nil => [],
            "/comments" => {
              nil => [],
              "/" => {
                :"[^./?]+" => {
                  nil => [],
                },
              },
            },
          },
        },
      }
      x = @router.instance_eval { _build_rexp(dict) { } }
      id = '[^./?]+'
      ok {x} == %r`\A/api/books/#{id}(?:(\z)|/comments(?:(\z)|/#{id}(\z)))\z`
    end

    spec "[!hs7vl] '(?:)' and '|' are added only if necessary." do
      dict = {
        "/api/books/" => {
          :"[^./?]+" => {
            "/comments" => {
              "/" => {
                :"[^./?]+" => {
                  nil => [],
                },
              },
            },
          },
        },
      }
      x = @router.instance_eval { _build_rexp(dict) { } }
      id = '[^./?]+'
      ok {x} == %r`\A/api/books/#{id}/comments/#{id}(\z)\z`
    end

    spec "[!7v7yo] nil key means leaf node and yields block argument." do
      dict = {
        "/api/books/" => {
          :"[^./?]+" => {
            nil => [9820],
            "/comments" => {
              "/" => {
                :"[^./?]+" => {
                  nil => [1549],
                },
              },
            },
          },
        },
      }
      actuals = []
      x = @router.instance_eval { _build_rexp(dict) {|a| actuals << a } }
      id = '[^./?]+'
      ok {x} == %r`\A/api/books/#{id}(?:(\z)|/comments/#{id}(\z))\z`
      ok {actuals} == [[9820], [1549]]
    end

    spec "[!hda6m] string key should be escaped." do
      dict = {
        "/api/books/" => {
          :"[^./?]+" => {
            ".json" => {
              nil => [],
            }
          }
        }
      }
      x = @router.instance_eval { _build_rexp(dict) { } }
      id = '[^./?]+'
      ok {x} == %r`\A/api/books/#{id}\.json(\z)\z`
    end

    spec "[!b9hxc] symbol key means regexp string." do
      dict = {
        "/api/books/" => {
          :'\d+' => {
            nil => [],
          },
        },
      }
      x = @router.instance_eval { _build_rexp(dict) { } }
      ok {x} == %r`\A/api/books/\d+(\z)\z`
    end

  end


  topic '#range_of_urlpath_param()' do

    spec "[!syrdh] returns Range object when urlpath_pattern contains just one param." do
      jet_router.instance_exec(self) do |_|
        r1 = range_of_urlpath_param('/books/:id')
        _.ok {r1} == (7..-1)
        _.ok {'/books/123'[r1]} == '123'
        r2 = range_of_urlpath_param('/books/:id.html')
        _.ok {r2} == (7..-6)
        _.ok {'/books/4567.html'[r2]} == '4567'
      end
    end

    spec "[!skh4z] returns nil when urlpath_pattern contains more than two params." do
      jet_router.instance_exec(self) do |_|
        _.ok {range_of_urlpath_param('/books/:book_id/comments/:comment_id')} == nil
        _.ok {range_of_urlpath_param('/books/:id(:format)')} == nil
      end
    end

    spec "[!acj5b] returns nil when urlpath_pattern contains no params." do
      jet_router.instance_exec(self) do |_|
        _.ok {range_of_urlpath_param('/books')} == nil
      end
    end

  end


  topic '#normalize_mapping_key()' do

    spec "[!r7cmk] converts keys into string." do
      mapping = [
        ['/books', {:GET=>book_list_api, :POST=>book_create_api}]
      ]
      Rack::JetRouter.new(mapping).instance_exec(self) do |_|
        dict = @fixed_urlpath_dict
        _.ok {dict['/books']} == {'GET'=>book_list_api, 'POST'=>book_create_api}
      end
    end

    spec "[!z9kww] allows 'ANY' as request method." do
      mapping = [
        ['/books', {'ANY'=>book_list_api, 'POST'=>book_create_api}]
      ]
      Rack::JetRouter.new(mapping).instance_exec(self) do |_|
        dict = @fixed_urlpath_dict
        _.ok {dict['/books']} == {'ANY'=>book_list_api, 'POST'=>book_create_api}
      end
    end

    spec "[!k7sme] raises error when unknown request method specified." do
      mapping = [
        ['/books', {"UNLOCK"=>book_list_api}]
      ]
      pr = proc { Rack::JetRouter.new(mapping) }
      ok {pr}.raise?(ArgumentError, '"UNLOCK": unknown request method.')
    end

  end


  topic '#should_redirect?' do

    spec "[!dsu34] returns false when request path is '/'." do
      jet_router.instance_exec(self) do |_|
        _.ok {should_redirect?(_.new_env('GET'   , '/'))} == false
        _.ok {should_redirect?(_.new_env('POST'  , '/'))} == false
        _.ok {should_redirect?(_.new_env('PUT'   , '/'))} == false
        _.ok {should_redirect?(_.new_env('DELETE', '/'))} == false
        _.ok {should_redirect?(_.new_env('HEAD'  , '/'))} == false
        _.ok {should_redirect?(_.new_env('PATCH' , '/'))} == false
      end
    end

    spec "[!ycpqj] returns true when request method is GET or HEAD." do
      jet_router.instance_exec(self) do |_|
        _.ok {should_redirect?(_.new_env('GET'   , '/index'))} == true
        _.ok {should_redirect?(_.new_env('HEAD'  , '/index'))} == true
      end
    end

    spec "[!7q8xu] returns false when request method is POST, PUT or DELETE." do
      jet_router.instance_exec(self) do |_|
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
      jet_router.instance_exec(self) do |_|
        _.ok {error_not_found(env)} == expected
      end
    end

  end


  topic '#error_not_allowed()' do

    spec "[!mjigf] returns 405 response." do
      expected = [405, {"Content-Type"=>"text/plain"}, ["405 Method Not Allowed"]]
      env = new_env('POST', '/')
      jet_router.instance_exec(self) do |_|
        _.ok {error_not_allowed(env)} == expected
      end
    end

  end


  topic '#initialize()' do

    spec "[!u2ff4] compiles urlpath mapping." do
      jet_router.instance_exec(self) do |_|
        id = '[^./?]+'
        expected = "
            \A
            (?:
                /api
                    (?:
                        /books
                            (?:/#{id}(\z)|/#{id}/edit(\z))
                    |
                        /books/#{id}/comments
                            (?:(\z)|/#{id}(\z))
                    )
            |
                /admin
                    /books
                        /#{id}(\z)
            )
            \z
        ".gsub(/\s+/, '')
        #_.ok {@urlpath_rexp} == Regexp.new(expected)
        _.ok {@urlpath_rexp} == %r`\A/a(?:pi/books/#{id}(?:(\z)|/(?:edit(\z)|comments(?:(\z)|/#{id}(\z))))|dmin/books/#{id}(\z))\z`
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
          [%r'\A/api/books/([^./?]+)\z',      ['id'], book_show_api, (11..-1)],
          [%r'\A/api/books/([^./?]+)/edit\z', ['id'], book_edit_api, (11..-6)],
          [%r'\A/api/books/([^./?]+)/comments\z',          ['book_id'], comment_create_api, (11..-10)],
          [%r'\A/api/books/([^./?]+)/comments/([^./?]+)\z', ['book_id', 'comment_id'], comment_update_api, nil],
          [%r'\A/admin/books/([^./?]+)\z',    ['id'], {'GET'    => admin_book_show_app,
                                                      'PUT'    => admin_book_update_app,
                                                      'DELETE' => admin_book_delete_app}, (13..-1)],
        ]
      end
    end

    spec "[!l63vu] handles urlpath pattern as fixed when no urlpath params." do
      mapping = [
        ['/api/books'      , book_list_api],
      ]
      router = Rack::JetRouter.new(mapping)
      router.instance_exec(self) do |_|
        dict = @fixed_urlpath_dict
        list = @variable_urlpath_list
        rexp = @urlpath_rexp
        _.ok {dict} == {'/api/books' => book_list_api}
        _.ok {list} == []
        _.ok {rexp} == /\A\z/
      end
    end

  end


  topic '#lookup()' do

    spec "[!ijqws] returns mapped object and urlpath parameter values when urlpath found." do
      ret = jet_router.lookup('/api/books/123')
      ok {ret} == [book_show_api, {"id"=>"123"}]
    end

    spec "[!vpdzn] returns nil when urlpath not found." do
      ok {jet_router.lookup('/api')}        == nil
      ok {jet_router.lookup('/api/book')}   == nil
      ok {jet_router.lookup('/api/books/')} == nil
    end

    spec "[!24khb] finds in fixed urlpaths at first." do
      ok {jet_router.lookup('/')}            == [welcome_app, nil]
      ok {jet_router.lookup('/api/books')}   == [book_list_api, nil]
      dict = {'GET'=>admin_book_list_app, 'POST'=>admin_book_create_app}
      ok {jet_router.lookup('/admin/books')} == [dict, nil]
    end

    spec "[!iwyzd] urlpath param value is nil when found in fixed urlpaths." do
      obj, vars = jet_router.lookup('/')
      ok {vars} == nil
      obj, vars = jet_router.lookup('/api/books')
      ok {vars} == nil
    end

    spec "[!upacd] finds in variable urlpath cache if it is enabled." do
      mapping = [
        ['/api/books/:id', book_show_api],
      ]
      r = Rack::JetRouter.new(mapping, urlpath_cache_size: 3)
      pair = r.lookup('/api/books/123')
      ok {pair} == [book_show_api, {"id"=>"123"}]
      r.instance_exec(self) do |_|
        _.ok {@variable_urlpath_cache} == {'/api/books/123'=>pair}
        #
        @variable_urlpath_cache['/api/books/999'] = [book_list_api, {"ID"=>"111"}]
      end
      pair = r.lookup('/api/books/999')
      ok {pair} == [book_list_api, {"ID"=>"111"}]
    end

    spec "[!84inr] caches result when variable urlpath cache enabled." do
      mapping = [
        ['/books/:id', book_show_api],
      ]
      r = Rack::JetRouter.new(mapping, urlpath_cache_size: 3)
      #
      pair1 = r.lookup('/books/1'); ok {pair1} == [book_show_api, {"id"=>"1"}]
      pair2 = r.lookup('/books/2'); ok {pair2} == [book_show_api, {"id"=>"2"}]
      pair3 = r.lookup('/books/3'); ok {pair3} == [book_show_api, {"id"=>"3"}]
      r.instance_exec(self) do |_|
        _.ok {@variable_urlpath_cache} == {
          '/books/1'=>pair1,
          '/books/2'=>pair2,
          '/books/3'=>pair3,
        }
      end
      #
      pair4 = r.lookup('/books/4'); ok {pair4} == [book_show_api, {"id"=>"4"}]
      r.instance_exec(self) do |_|
        _.ok {@variable_urlpath_cache} == {
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
      r = Rack::JetRouter.new(mapping, urlpath_cache_size: 3)
      #
      pair1 = r.lookup('/books/1')
      pair2 = r.lookup('/books/2')
      pair3 = r.lookup('/books/3')
      pair4 = r.lookup('/books/4')
      r.instance_exec(self) do |_|
        _.ok {@variable_urlpath_cache} == {
          '/books/2'=>pair2,
          '/books/3'=>pair3,
          '/books/4'=>pair4,
        }
      end
      #
      ok {r.lookup('/books/3')} == pair3
      r.instance_exec(self) do |_|
        _.ok {@variable_urlpath_cache} == {
          '/books/2'=>pair2,
          '/books/4'=>pair4,
          '/books/3'=>pair3,
        }
      end
      #
      ok {r.lookup('/books/1')} == pair1
      r.instance_exec(self) do |_|
        _.ok {@variable_urlpath_cache} == {
          '/books/4'=>pair4,
          '/books/3'=>pair3,
          '/books/1'=>pair1,
        }
      end
    end

  end


  topic '#call()' do

    spec "[!hse47] invokes app mapped to request urlpath." do
      ok {jet_router.call(new_env(:GET, '/api/books/123'))}   == [200, {}, ["book_show_api"]]
      ok {jet_router.call(new_env(:PUT, '/admin/books/123'))} == [200, {}, ["admin_book_update_app"]]
    end

    spec "[!fpw8x] finds mapped app according to env['PATH_INFO']." do
      ok {jet_router.call(new_env(:GET, '/api/books'))}     == [200, {}, ["book_list_api"]]
      ok {jet_router.call(new_env(:GET, '/api/books/123'))} == [200, {}, ["book_show_api"]]
    end

    spec "[!wxt2g] guesses correct urlpath and redirects to it automaticaly when request path not found." do
      headers = {"Content-Type"=>"text/plain", "Location"=>"/api/books"}
      content = "Redirect to /api/books"
      ok {jet_router.call(new_env(:GET, '/api/books/'))}    == [301, headers, [content]]
      #
      headers = {"Content-Type"=>"text/plain", "Location"=>"/api/books/78"}
      content = "Redirect to /api/books/78"
      ok {jet_router.call(new_env(:GET, '/api/books/78/'))} == [301, headers, [content]]
    end

    spec "[!3vsua] doesn't redict automatically when request path is '/'." do
      r = Rack::JetRouter.new([['/api/books', book_list_api]])
      ok {r.call(new_env(:GET, '/'))} == [404, {"Content-Type"=>"text/plain"}, ["404 Not Found"]]
    end

    spec "[!hyk62] adds QUERY_STRING to redirect location." do
      headers = {"Content-Type"=>"text/plain", "Location"=>"/api/books?x=1&y=2"}
      content = "Redirect to /api/books?x=1&y=2"
      env = new_env(:GET, '/api/books/', {"QUERY_STRING"=>"x=1&y=2"})
      ok {jet_router.call(env)} == [301, headers, [content]]
    end

    spec "[!30x0k] returns 404 when request urlpath not found." do
      expected = [404, {"Content-Type"=>"text/plain"}, ["404 Not Found"]]
      ok {jet_router.call(new_env(:GET, '/xxx'))} == expected
      ok {jet_router.call(new_env(:GET, '/api/book'))} == expected
    end

    topic "[!gclbs] if mapped object is a Hash..." do

      spec "[!p1fzn] invokes app mapped to request method." do
        ok {jet_router.call(new_env(:GET,    '/admin/books'))}     == [200, {}, ["admin_book_list_app"]]
        ok {jet_router.call(new_env(:POST,   '/admin/books'))}     == [200, {}, ["admin_book_create_app"]]
        ok {jet_router.call(new_env(:GET,    '/admin/books/123'))} == [200, {}, ["admin_book_show_app"]]
        ok {jet_router.call(new_env(:PUT,    '/admin/books/123'))} == [200, {}, ["admin_book_update_app"]]
        ok {jet_router.call(new_env(:DELETE, '/admin/books/123'))} == [200, {}, ["admin_book_delete_app"]]
      end

      spec "[!5m64a] returns 405 when request method is not allowed." do
        expected = [405, {"Content-Type"=>"text/plain"}, ["405 Method Not Allowed"]]
        ok {jet_router.call(new_env(:PUT,    '/admin/books'))} == expected
        ok {jet_router.call(new_env(:FOOBAR, '/admin/books'))} == expected
      end

      spec "[!ys1e2] uses GET method when HEAD is not mapped." do
        ok {jet_router.call(new_env(:HEAD,    '/admin/books'))}     == [200, {}, ["admin_book_list_app"]]
        ok {jet_router.call(new_env(:HEAD,    '/admin/books/123'))} == [200, {}, ["admin_book_show_app"]]
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

    spec "[!2c32f] stores urlpath parameters as env['rack.urlpath_params']." do
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


  topic '#each()' do

    spec "[!ep0pw] yields pair of urlpath pattern and app." do
      arr = []
      jet_router.each do |upath, app|
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


  topic 'REQUEST_METHODS' do

    spec "[!haggu] contains available request methods." do
      Rack::JetRouter::REQUEST_METHODS.each do |k, v|
        ok {k}.is_a?(String)
        ok {v}.is_a?(Symbol)
        ok {v.to_s} == k
      end
    end

  end


end


end
