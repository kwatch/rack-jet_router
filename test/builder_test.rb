# -*- coding: utf-8 -*-

###
### $Release: 0.0.0 $
### $Copyright: copyright(c) 2015 kwatch@gmail.com all rights reserved $
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
        dict = @builder.build_tree(mapping)
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
        dict = @builder.build_tree(mapping) {|path, item, _| actuals << [path, item] }
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
        dict = @builder.build_tree(mapping) {|path, _, fixed_p|
          actuals << [path, fixed_p]
        }
        id = '[^./?]+'
        ok {actuals} == [
          ["/api/books/new", false],
          ["/api/books/:id", true],
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
        dict = @builder.build_tree(mapping)
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
        dict = @builder.build_tree(mapping) do |path, item, fixed_p|
          actuals << [path, item, fixed_p]
        end
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
        dict = @builder.build_tree(mapping)
        tuple = _find(dict, nil)
        id = '[^./?]+'
        ok {tuple[0]} == %r`\A/api/books/(#{id})\z`
      end

      spec "[!po6o6] param regexp should be stored into nested dict as a Symbol." do
        mapping = [
          ["/api/books/:id", book_show_api],
        ]
        dict = @builder.build_tree(mapping)
        ok {dict["/api/books/"].keys()} == [:'[^./?]+']
      end

      spec "[!zoym3] urlpath string should be escaped." do
        mapping = [
          ["/api/books.dir.tmp/:id.tar.gz", book_show_api],
        ]
        dict = @builder.build_tree(mapping)
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
        dict = @builder.build_tree(mapping)
        tuple = _find(dict, nil)
        id = '[^./?]+'
        ok {tuple[0]} == %r`\A/api/books/(#{id})(?:\.(#{id}))?(?:\.gz)?\z`
      end

      spec "[!kz8m7] range object should be included into tuple if only one param exist." do
        mapping = [
          ["/api/books/:id.json", book_show_api],
        ]
        dict = @builder.build_tree(mapping)
        tuple = _find(dict, nil)
        id = '[^./?]+'
        ok {tuple} == [%r`\A/api/books/(#{id})\.json\z`,
                       ["id"], book_show_api, (11..-6)]
      end

      spec "[!c6xmp] tuple should be stored into nested dict with key 'nil'." do
        mapping = [
          ["/api/books/:id.json", book_show_api],
        ]
        dict = @builder.build_tree(mapping)
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
        dict = @builder.build_tree(mapping) {|*args| actuals << args }
        id = '[^./?]+'
        ok {actuals} == [
          ["/api/books/new", book_new_api , false],
          ["/api/books/:id", book_show_api, true],
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
        @builder.instance_eval do
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
        @builder.instance_eval do
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
        @builder.instance_eval do
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
        @builder.instance_eval do
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
        @builder.instance_eval do
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
        s1, s2 = @builder.instance_eval { _param_patterns("id", nil) {|a| x = a } }
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

      spec "[!syrdh] returns Range object when urlpath_pattern contains just one param." do
        @builder.instance_exec(self) do |_|
          r1 = _range_of_urlpath_param('/books/:id')
          _.ok {r1} == (7..-1)
          _.ok {'/books/123'[r1]} == '123'
          r2 = _range_of_urlpath_param('/books/:id.html')
          _.ok {r2} == (7..-6)
          _.ok {'/books/4567.html'[r2]} == '4567'
        end
      end

      spec "[!skh4z] returns nil when urlpath_pattern contains more than two params." do
        @builder.instance_exec(self) do |_|
          _.ok {_range_of_urlpath_param('/books/:book_id/comments/:comment_id')} == nil
          _.ok {_range_of_urlpath_param('/books/:id(:format)')} == nil
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
