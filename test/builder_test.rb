# -*- coding: utf-8 -*-

###
### $Release: 0.0.0 $
### $Copyright: copyright(c) 2015 kwatch@gmail.com $
### $License: MIT License $
###

require_relative './shared'


Oktest.scope do


  topic Rack::JetRouter::Builder do

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

    def _find(d, k)
      return d.key?(k) ? d[k] : _find(d.to_a[0][1], k)
    end

    before do
      router = Rack::JetRouter.new([])
      @builder = Rack::JetRouter::Builder.new(router)
    end


    topic '#build_tree()' do

      spec "[!6oa05] builds nested hash object from mapping data." do
        endpoint_pairs = [
          ['/api/books/:id'     , book_show_api],
          ['/api/books/:id/edit', book_edit_api],
          ['/api/books/:book_id/comments'            , comment_create_api],
          ['/api/books/:book_id/comments/:comment_id', comment_update_api],
        ]
        dict = @builder.build_tree(endpoint_pairs)
        id = '[^./?]+'
        ok {dict} == {
          "/api/books/" => {
            :'[^./?]+' => {
              nil => [/\A\/api\/books\/(#{id})\z/,
                      ["id"], book_show_api, 11..-1, nil],
              "/" => {
                "edit" => {
                  nil => [/\A\/api\/books\/(#{id})\/edit\z/,
                          ["id"], book_edit_api, 11..-6, nil],
                },
                "comments" => {
                  nil => [/\A\/api\/books\/(#{id})\/comments\z/,
                          ["book_id"], comment_create_api, 11..-10, nil],
                  "/" => {
                    :'[^./?]+' => {
                      nil => [/\A\/api\/books\/(#{id})\/comments\/(#{id})\z/,
                              ["book_id", "comment_id"], comment_update_api, (11..-1), '/comments/'],
                    },
                  },
                },
              },
            },
          },
        }
      end

      spec "[!uyupj] handles urlpath parameter such as ':id'." do
        endpoint_pairs = [
          ["/api/books/:book_id/comments"    , {"POST"=>comment_create_api}],
          ["/api/books/:book_id/comments/:id", {"PUT"=>comment_update_api}],
        ]
        dict = @builder.build_tree(endpoint_pairs)
        id = '[^./?]+'
        ok {dict} == {
          "/api/books/" => {
            :"[^./?]+" => {
              "/comments" => {
                nil => [%r`\A/api/books/(#{id})/comments\z`,
                        ["book_id"], {"POST"=>comment_create_api}, (11..-10), nil],
                "/" => {
                  :"[^./?]+" => {
                    nil => [%r`\A/api/books/(#{id})/comments/(#{id})\z`,
                            ["book_id", "id"], {"PUT"=>comment_update_api}, (11..-1), '/comments/'],
                  },
                },
              },
            },
          },
        }
      end

      spec "[!j9cdy] handles optional urlpath parameter such as '(.:format)'." do
        endpoint_pairs = [
          ["/api/books(.:format)"    , {"GET"=>book_list_api}],
          ["/api/books/:id(.:format)", {"GET"=>book_show_api}],
        ]
        dict = @builder.build_tree(endpoint_pairs)
        id = '[^./?]+'
        ok {dict} == {
          "/api/books" => {
            :"(?:\\.[^./?]+)?" => {
              nil => [%r`\A/api/books(?:\.(#{id}))?\z`,
                      ["format"], {"GET"=>book_list_api}, nil, nil]},
            "/" => {
              :"[^./?]+" => {
                :"(?:\\.[^./?]+)?" => {
                  nil => [%r`\A/api/books/(#{id})(?:\.(#{id}))?\z`,
                          ["id", "format"], {"GET"=>book_show_api}, nil, nil],
                },
              },
            },
          },
        }
      end

      spec "[!akkkx] converts urlpath param into regexp." do
        endpoint_pairs = [
          ["/api/books/:id", book_show_api],
        ]
        dict = @builder.build_tree(endpoint_pairs)
        tuple = _find(dict, nil)
        id = '[^./?]+'
        ok {tuple[0]} == %r`\A/api/books/(#{id})\z`
      end

      spec "[!lwgt6] handles '|' (OR) pattern in '()' such as '(.html|.json)'." do
        endpoint_pairs = [
          ["/api/books/:id(.html|.json)", book_show_api],
        ]
        dict = @builder.build_tree(endpoint_pairs)
        tuple = _find(dict, nil)
        id = '[^./?]+'
        ok {tuple[0]} == %r`\A/api/books/(#{id})(?:\.html|\.json)?\z`
      end

      spec "[!po6o6] param regexp should be stored into nested dict as a Symbol." do
        endpoint_pairs = [
          ["/api/books/:id", book_show_api],
        ]
        dict = @builder.build_tree(endpoint_pairs)
        ok {dict["/api/books/"].keys()} == [:'[^./?]+']
      end

      spec "[!zoym3] urlpath string should be escaped." do
        endpoint_pairs = [
          ["/api/books.dir.tmp/:id.tar.gz", book_show_api],
        ]
        dict = @builder.build_tree(endpoint_pairs)
        tuple = _find(dict, nil)
        id = '[^./?]+'
        ok {tuple[0]} == %r`\A/api/books\.dir\.tmp/(#{id})\.tar\.gz\z`
      end

      spec "[!o642c] remained string after param should be handled correctly." do
        endpoint_pairs = [
          ["/api/books/:id(.:format)(.gz)", book_show_api],
        ]
        dict = @builder.build_tree(endpoint_pairs)
        tuple = _find(dict, nil)
        id = '[^./?]+'
        ok {tuple[0]} == %r`\A/api/books/(#{id})(?:\.(#{id}))?(?:\.gz)?\z`
      end

      spec "[!kz8m7] range object should be included into tuple if only one param exist." do
        endpoint_pairs = [
          ["/api/books/:id.json", book_show_api],
        ]
        dict = @builder.build_tree(endpoint_pairs)
        tuple = _find(dict, nil)
        id = '[^./?]+'
        ok {tuple} == [%r`\A/api/books/(#{id})\.json\z`,
                       ["id"], book_show_api, (11..-6), nil]
      end

      spec "[!c6xmp] tuple should be stored into nested dict with key 'nil'." do
        endpoint_pairs = [
          ["/api/books/:id.json", book_show_api],
        ]
        dict = @builder.build_tree(endpoint_pairs)
        id = '[^./?]+'
        ok {dict} == {
          "/api/books/" => {
            :"[^./?]+" => {
              ".json" => {
                nil => [%r`\A/api/books/(#{id})\.json\z`,
                        ["id"], book_show_api, (11..-6), nil],
              },
            },
          },
        }
      end

    end


    topic '#traverse_mapping()' do

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
        @builder.traverse_mapping(mapping1) {|*args| actuals1 << args }
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
        @builder.traverse_mapping(mapping2) {|*args| actuals2 << args }
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
        @builder.traverse_mapping(mapping) {|*args| actuals << args }
        ok {actuals} == [
          ["/api/books"    , Map.new.update("GET"=>book_list_api)],
          ["/api/books/new", Map.new.update("GET"=>book_new_api) ],
          ["/api/books/:id", Map.new.update("GET"=>book_show_api, "PUT"=>book_edit_api)],
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
        @builder.traverse_mapping(mapping) {|*args| actuals << args }
        ok {actuals} ==  [
          ["/api/books"         , book_list_api],
          ["/api/books/new"     , book_new_api],
          ["/api/books/:id"     , book_show_api],
          ["/api/books/:id/edit", book_edit_api],
          ["/api/books/:book_id/comments"            , comment_create_api],
          ["/api/books/:book_id/comments/:comment_id", comment_update_api],
        ]
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
        @builder.traverse_mapping(mapping) {|path, item| actuals << [path, item] }
        ok {actuals} == [
          ["/api/books/new", {"GET"=>book_new_api}],
          ["/api/books/:id", {"GET"=>book_show_api, "DELETE"=>book_delete_api}],
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
        @builder.traverse_mapping(mapping) {|*args| actuals << args }
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
          d2 = @builder.instance_eval { _next_dict(dict, "a") }
          ok {d2} == {"b" => 10}
          ok {dict} == {"a" => {"b" => 10}}
        end

      end

      spec "[!3ndpz] returns next dict." do
        dict = {"aa1" => {"aa2"=>10}}
        d2 = @builder.instance_eval { _next_dict(dict, "aa8") }
        ok {d2} == {}
        ok {dict} == {"aa" => {"1" => {"aa2"=>10}, "8" => {}}}
        ok {dict["aa"]["8"]}.same?(d2)
      end

      spec "[!5fh08] keeps order of keys in dict." do
        dict = {"aa1" => {"aa2"=>10}, "bb1" => {"bb2"=>20}, "cc1" => {"cc2"=>30}}
        d2 = @builder.instance_eval { _next_dict(dict, "bb8") }
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
        d2 = @builder.instance_eval { _next_dict(dict, "bb1") }
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
        d2 = @builder.instance_eval { _next_dict(dict, "mm1") }
        ok {d2} == {}
        ok {dict} == {"aa1" => {"aa2" => 10}, nil => ["foo"], "mm1" => {}}
        ok {dict["mm1"]}.same?(d2)
      end

      case_when "[!46o9b] if existing key is same as common prefix..." do

        spec "[!4ypls] not replace existing key." do
          dict = {"aa1" => {"aa2" => 10}, "bb1" => {"bb2" => 20}}
          aa1 = dict["aa1"]
          d2 = @builder.instance_eval { _next_dict(dict, "aa1mm2") }
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
          d2 = @builder.instance_eval { _next_dict(dict, "aa") }
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
          d2 = @builder.instance_eval { _next_dict(dict, "bb7") }
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
          d2 = @builder.instance_eval { _next_dict(dict, "mm1") }
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
        t = @builder.instance_eval { _common_prefix("baar", "bazz") }
        prefix, rest1, rest2 = t
        ok {prefix} == "ba"
        ok {rest1}  == "ar"
        ok {rest2}  == "zz"
      end

      spec "[!86tsd] calculates common prefix of two strings." do
        t = @builder.instance_eval { _common_prefix("bar", "barkuz") }
        prefix, rest1, rest2 = t
        ok {prefix} == "bar"
        ok {rest1}  == ""
        ok {rest2}  == "kuz"
        #
        t = @builder.instance_eval { _common_prefix("barrab", "bar") }
        prefix, rest1, rest2 = t
        ok {prefix} == "bar"
        ok {rest1}  == "rab"
        ok {rest2}  == ""
      end

    end


    topic '#_param_patterns()' do

      spec "[!j90mw] returns '[^./?]+' and '([^./?]+)' if param specified." do
        x = nil
        s1, s2 = @builder.instance_eval { _param_patterns(":id", nil) {|a| x = a } }
        ok {s1} == '[^./?]+'
        ok {s2} == '([^./?]+)'
        ok {x} == "id"
      end

      spec "[!raic7] returns '(?:\.[^./?]+)?' and '(?:\.([^./?]+))?' if optional param is '(.:format)'." do
        x = nil
        s1, s2 = @builder.instance_eval { _param_patterns(nil, ".:format") {|a| x = a } }
        ok {s1} == '(?:\.[^./?]+)?'
        ok {s2} == '(?:\.([^./?]+))?'
        ok {x} == "format"
      end

      spec "[!69yj9] optional string can contains other params." do
        arr = []
        s1, s2 = @builder.instance_eval { _param_patterns(nil, ":yr-:mo-:dy") {|a| arr << a } }
        ok {s1} == '(?:[^./?]+\-[^./?]+\-[^./?]+)?'
        ok {s2} == '(?:([^./?]+)\-([^./?]+)\-([^./?]+))?'
        ok {arr} == ["yr", "mo", "dy"]
      end

      spec "[!oh9c6] optional string can have '|' (OR)." do
        arr = []
        s1, s2 = @builder.instance_eval { _param_patterns(nil, ".html|.json") {|a| arr << a } }
        ok {s1} == '(?:\.html|\.json)?'
        ok {s2} == '(?:\.html|\.json)?'
        ok {arr} == []
      end

    end


    topic '#build_rexp()' do

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
        x = @builder.build_rexp(dict) { }
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
        x = @builder.build_rexp(dict) { }
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
        x = @builder.build_rexp(dict) {|a| actuals << a }
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
        x = @builder.build_rexp(dict) { }
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
        x = @builder.build_rexp(dict) { }
        ok {x} == %r`\A/api/books/\d+(\z)\z`
      end

    end


    topic '#range_of_urlpath_param()' do

      spec "[!93itq] returns nil if urlpath pattern includes optional parameters." do
        @builder.instance_exec(self) do |_|
          r1 = _range_of_urlpath_param('/books(.:format)')
          _.ok {r1} == nil
        end
      end

      spec "[!syrdh] returns Range object when urlpath_pattern contains just one param." do
        @builder.instance_exec(self) do |_|
          t = _range_of_urlpath_param('/books/:id')
          _.ok {t} == [(7..-1), nil]
          _.ok {'/books/123'[t[0]]} == '123'
          #
          t = _range_of_urlpath_param('/books/:id.html')
          _.ok {t} == [(7..-6), nil]
          _.ok {'/books/4567.html'[t[0]]} == '4567'
        end
      end

      spec "[!elsdx] returns Range and separator string when urlpath_pattern contains two params." do
        @builder.instance_exec(self) do |_|
          t = _range_of_urlpath_param('/books/:id/comments/:comment_id.json')
          _.ok {t} == [(7..-6), '/comments/']
          _.ok {'/books/123/comments/456.json'[t[0]]} == "123/comments/456"
          _.ok {'/books/123/comments/456.json'[t[0]].split(t[1])} == ["123", "456"]
          #
          t = _range_of_urlpath_param('/books/:id/comments/:comment_id')
          _.ok {t} == [(7..-1), '/comments/']
          _.ok {'/books/123/comments/456'[t[0]]} == "123/comments/456"
          _.ok {'/books/123/comments/456'[t[0]].split(t[1])} == ["123", "456"]
        end
      end

      spec "[!skh4z] returns nil when urlpath_pattern contains more than two params." do
        @builder.instance_exec(self) do |_|
          _.ok {_range_of_urlpath_param('/books/:book_id/comments/:c_id/foo/:foo_id')} == nil
        end
      end

      spec "[!acj5b] returns nil when urlpath_pattern contains no params." do
        @builder.instance_exec(self) do |_|
          _.ok {_range_of_urlpath_param('/books')} == nil
        end
      end

    end


  end


end
