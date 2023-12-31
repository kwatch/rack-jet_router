# -*- coding: utf-8 -*-
# frozen_string_literal: true

###
### $Release: 0.0.0 $
### $Copyright: copyright(c) 2015 kwatch@gmail.com $
### $License: MIT License $
###

require 'rack'


module Rack


  ##
  ## Jet-speed router class, derived from Keight.rb.
  ##
  ## Example #1:
  ##     ### (assume that 'xxxx_app' are certain Rack applications.)
  ##     mapping = {
  ##         "/"                       => home_app,
  ##         "/api" => {
  ##             "/books" => {
  ##                 ""                => books_app,
  ##                 "/:id(.:format)"  => book_app,
  ##                 "/:book_id/comments/:comment_id" => comment_app,
  ##             },
  ##         },
  ##         "/admin" => {
  ##             "/books"              => admin_books_app,
  ##         },
  ##     }
  ##     router = Rack::JetRouter.new(mapping)
  ##     router.lookup("/api/books/123.html")
  ##         #=> [book_app, {"id"=>"123", "format"=>"html"}]
  ##     status, headers, body = router.call(env)
  ##
  ## Example #2:
  ##     mapping = [
  ##         ["/"                       , {GET: home_app}],
  ##         ["/api", [
  ##             ["/books", [
  ##                 [""                , {GET: book_list_app, POST: book_create_app}],
  ##                 ["/:id(.:format)"  , {GET: book_show_app, PUT: book_update_app}],
  ##                 ["/:book_id/comments/:comment_id", {POST: comment_create_app}],
  ##             ]],
  ##         ]],
  ##         ["/admin", [
  ##             ["/books"              , {ANY: admin_books_app}],
  ##         ]],
  ##     ]
  ##     router = Rack::JetRouter.new(mapping)
  ##     router.lookup("/api/books/123")
  ##         #=> [{"GET"=>book_show_app, "PUT"=>book_update_app}, {"id"=>"123", "format"=>nil}]
  ##     status, headers, body = router.call(env)
  ##
  ## Example #3:
  ##     class Map < Hash         # define subclass of Hash
  ##     end
  ##     def Map(**kwargs)        # define helper method to create Map object easily
  ##       return Map.new.update(kwargs)
  ##     end
  ##     mapping = {
  ##         "/"                       => Map(GET: home_app),
  ##         "/api" => {
  ##             "/books" => {
  ##                 ""                => Map(GET: book_list_app, POST: book_create_app),
  ##                 "/:id(.:format)"  => Map(GET: book_show_app, PUT: book_update_app),
  ##                 "/:book_id/comments/:comment_id" => Map(POST: comment_create_app),
  ##             },
  ##         },
  ##         "/admin" => {
  ##             "/books"              => Map(ANY: admin_books_app),
  ##         },
  ##     }
  ##     router = Rack::JetRouter.new(mapping)
  ##     router.lookup("/api/books/123")
  ##         #=> [{"GET"=>book_show_app, "PUT"=>book_update_app}, {"id"=>"123", "format"=>nil}]
  ##     status, headers, body = router.call(env)
  ##
  class JetRouter

    RELEASE = '$Release: 0.0.0 $'.split()[1]

    #; [!haggu] contains available request methods.
    REQUEST_METHODS = %w[GET POST PUT DELETE PATCH HEAD OPTIONS TRACE LINK UNLINK] \
                        .each_with_object({}) {|s, d| d[s] = s.intern }

    def initialize(mapping, cache_size: 0, env_key: 'rack.urlpath_params',
                            int_param: nil,          # ex: /(?:\A|_)id\z/
                            urlpath_cache_size: 0,   # for backward compatibility
                            _enable_range: true)     # undocumentend keyword arg
      @env_key = env_key
      @int_param = int_param
      #; [!21mf9] 'urlpath_cache_size:' kwarg is available for backward compatibility.
      @cache_size = [cache_size, urlpath_cache_size].max()
      #; [!5tw57] cache is disabled when 'cache_size:' is zero.
      @cache_dict = @cache_size > 0 ? {} : nil
      ##
      ## Pair list of endpoint and Rack app.
      ## ex:
      ##   [
      ##     ["/api/books"      , books_app ],
      ##     ["/api/books/:id"  , book_app  ],
      ##     ["/api/orders"     , orders_app],
      ##     ["/api/orders/:id" , order_app ],
      ##   ]
      ##
      @all_endpoints = []
      ##
      ## Endpoints without any path parameters.
      ## ex:
      ##   {
      ##     "/"           => home_app,
      ##     "/api/books"  => books_app,
      ##     "/api/orders" => orders_app,
      ##   }
      ##
      @fixed_endpoints = {}
      ##
      ## Endpoints with one or more path parameters.
      ## ex:
      ##   [
      ##     [%r!\A/api/books/([^./?]+)\z! , ["id"], book_app , (11..-1)],
      ##     [%r!\A/api/orders/([^./?]+)\z!, ["id"], order_app, (12..-1)],
      ##   ]
      ##
      @variable_endpoints = []
      ##
      ## Combined regexp of variable endpoints.
      ## ex:
      ##   %r!\A/api/(?:books/[^./?]+(\z)|orders/[^./?]+(\z))\z!
      ##
      @urlpath_rexp = nil
      #
      #; [!x2l32] gathers all endpoints.
      builder = Builder.new(self, _enable_range)
      param_rexp = /:\w+|\(.*?\)/
      tmplist = []
      builder.traverse_mapping(mapping) do |path, item|
        @all_endpoints << [path, item]
        #; [!l63vu] handles urlpath pattern as fixed when no urlpath params.
        if path !~ param_rexp
          @fixed_endpoints[path] = item
        #; [!ec0av] treats '/foo(.html|.json)' as three fixed urlpaths.
        #; [!ylyi0] stores '/foo' as fixed path when path pattern is '/foo(.:format)'.
        elsif path =~ /\A([^:\(\)]*)\(([^\(\)]+)\)\z/
          @fixed_endpoints[$1] = item unless $1.empty?
          arr = []
          $2.split('|').each do |s|
            next if s.empty?
            if s.include?(':')
              arr << s
            else
              @fixed_endpoints[$1 + s] = item
            end
          end
          tmplist << ["#{$1}(#{arr.join('|')})", item] unless arr.empty?
        else
          tmplist << [path, item]
        end
      end
      #; [!saa1a] compiles compound urlpath regexp.
      tree = builder.build_tree(tmplist)
      @urlpath_rexp = builder.build_rexp(tree) do |tuple|
        #; [!f1d7s] builds variable endpoint list.
        @variable_endpoints << tuple
      end
    end

    attr_reader :urlpath_rexp

    ## Finds rack app according to PATH_INFO and REQUEST_METHOD and invokes it.
    def call(env)
      #; [!fpw8x] finds mapped app according to env['PATH_INFO'].
      req_path = env['PATH_INFO']
      obj, param_values = lookup(req_path)
      #; [!wxt2g] guesses correct urlpath and redirects to it automaticaly when request path not found.
      #; [!3vsua] doesn't redict automatically when request path is '/'.
      if ! obj && should_redirect?(env)
        location = req_path.end_with?("/") ? req_path[0..-2] : req_path + "/"
        obj, param_values = lookup(location)
        if obj
          #; [!hyk62] adds QUERY_STRING to redirect location.
          qs = env['QUERY_STRING']
          location = "#{location}?#{qs}" if qs && ! qs.empty?
          return redirect_to(location)
        end
      end
      #; [!30x0k] returns 404 when request urlpath not found.
      return error_not_found(env) unless obj
      #; [!gclbs] if mapped object is a Hash...
      if obj.is_a?(Hash)
        #; [!p1fzn] invokes app mapped to request method.
        #; [!5m64a] returns 405 when request method is not allowed.
        #; [!ys1e2] uses GET method when HEAD is not mapped.
        #; [!2hx6j] try ANY method when request method is not mapped.
        dict = obj
        req_meth = env['REQUEST_METHOD']
        app = dict[req_meth] || (req_meth == 'HEAD' ? dict['GET'] : nil) || dict['ANY']
        return error_not_allowed(env) unless app
      else
        app = obj
      end
      #; [!2c32f] stores urlpath parameter values into env['rack.urlpath_params'].
      store_param_values(env, param_values)
      #; [!hse47] invokes app mapped to request urlpath.
      return app.call(env)   # make body empty when HEAD?
    end

    ## Finds app or Hash mapped to request path.
    ##
    ## ex:
    ##    lookup('/api/books/123')   #=> [BookApp, {"id"=>"123"}]
    def lookup(req_path)
      #; [!24khb] finds in fixed urlpaths at first.
      #; [!iwyzd] urlpath param value is nil when found in fixed urlpaths.
      obj = @fixed_endpoints[req_path]
      return obj, nil if obj
      #; [!upacd] finds in variable urlpath cache if it is enabled.
      #; [!1zx7t] variable urlpath cache is based on LRU.
      cache = @cache_dict
      if cache && (pair = cache.delete(req_path))
        cache[req_path] = pair
        return pair
      end
      #; [!vpdzn] returns nil when urlpath not found.
      m = @urlpath_rexp.match(req_path)
      return nil unless m
      index = m.captures.index('')
      return nil unless index
      #; [!ijqws] returns mapped object and urlpath parameter values when urlpath found.
      full_urlpath_rexp, param_names, obj, range, sep = @variable_endpoints[index]
      if range
        ## "/books/123"[7..-1] is faster than /\A\/books\/(\d+)\z/.match("/books/123")[1]
        str = req_path[range]
        ## `"/a/1/b/2"[3..-1].split('/b/')` is faster than `%r!\A/a/(\d+)/b/(\d+)\z!.match("/a/1/b/2").captures`
        values = sep ? str.split(sep) : [str]
      else
        m = full_urlpath_rexp.match(req_path)
        values = m.captures
      end
      param_values = build_param_values(param_names, values)
      #; [!84inr] caches result when variable urlpath cache enabled.
      if cache
        cache.shift() if cache.length >= @cache_size
        cache[req_path] = [obj, param_values]
      end
      return obj, param_values
    end

    alias find lookup      # :nodoc:      # for backward compatilibity

    ## Yields pair of urlpath pattern and app.
    def each(&block)
      #; [!ep0pw] yields pair of urlpath pattern and app.
      @all_endpoints.each(&block)
    end

    protected

    ## Returns [404, {...}, [...]]. Override in subclass if necessary.
    def error_not_found(env)
      #; [!mlruv] returns 404 response.
      return [404, {"Content-Type"=>"text/plain"}, ["404 Not Found"]]
    end

    ## Returns [405, {...}, [...]]. Override in subclass if necessary.
    def error_not_allowed(env)
      #; [!mjigf] returns 405 response.
      return [405, {"Content-Type"=>"text/plain"}, ["405 Method Not Allowed"]]
    end

    ## Returns false when request path is '/' or request method is not GET nor HEAD.
    ## (It is not recommended to redirect when request method is POST, PUT or DELETE,
    ##  because browser doesn't handle redirect correctly on those methods.)
    def should_redirect?(env)
      #; [!dsu34] returns false when request path is '/'.
      #; [!ycpqj] returns true when request method is GET or HEAD.
      #; [!7q8xu] returns false when request method is POST, PUT or DELETE.
      return false if env['PATH_INFO'] == '/'
      req_method = env['REQUEST_METHOD']
      return req_method == 'GET' || req_method == 'HEAD'
    end

    ## Returns [301, {"Location"=>location, ...}, [...]]. Override in subclass if necessary.
    def redirect_to(location)
      #; [!9z57v] returns 301 and 'Location' header.
      content = "Redirect to #{location}"
      return [301, {"Content-Type"=>"text/plain", "Location"=>location}, [content]]
    end

    ## Stores urlpath parameter values into `env['rack.urlpath_params']`. Override if necessary.
    def store_param_values(env, values)
      #; [!94riv] stores urlpath param values into `env['rack.urlpath_params']`.
      #; [!9he9h] env key can be changed by `env_key:` kwarg of 'JetRouter#initialize()'.
      env[@env_key] = values if values
    end

    ## Returns Hash object representing urlpath parameter values. Override if necessary.
    def build_param_values(names, values)
      #; [!qxcis] when 'int_param:' kwarg is specified to constructor...
      if (int_param_rexp = @int_param)
        #; [!l6p84] converts urlpath pavam value into integer.
        d = {}
        for name, val in names.zip(values)
          d[name] = int_param_rexp.match?(name) ? val.to_i : val
        end
        return d
      #; [!vrbo5] else...
      else
        #; [!yc9n8] creates new Hash object from param names and values.
        return Hash[names.zip(values)]
      end
    end

    public

    def normalize_method_mapping(dict)   # called from Builder class
      #; [!r7cmk] converts keys into string.
      #; [!z9kww] allows 'ANY' as request method.
      #; [!k7sme] raises error when unknown request method specified.
      #; [!itfsd] returns new Hash object.
      #; [!gd08f] if arg is an instance of Hash subclass, returns new instance of it.
      request_methods = REQUEST_METHODS
      #newdict = {}
      newdict = dict.class.new
      dict.each do |meth_sym, app|
        meth_str = meth_sym.to_s
        request_methods[meth_str] || meth_str == 'ANY'  or
          raise ArgumentError.new("#{meth_sym}: unknown request method.")
        newdict[meth_str] = app
      end
      return newdict
    end

    ## Returns regexp string of path parameter. Override if necessary.
    def param2rexp(param)   # called from Builder class
      #; [!6sd9b] returns regexp string according to param name.
      #; [!rfvk2] returns '\d+' if param name matched to int param regexp.
      return (rexp = @int_param) && rexp.match?(param) ? '\d+' : '[^./?]+'
    end


    class Builder

      def initialize(router, enable_range=true)
        @router = router
        @enable_range = enable_range
      end

      def traverse_mapping(mapping, &block)
        _traverse_mapping(mapping, "", mapping.class, &block)
        nil
      end

      private

      def _traverse_mapping(mapping, base_path, mapping_class, &block)
        #; [!9s3f0] supports both nested list mapping and nested dict mapping.
        mapping.each do |sub_path, item|
          full_path = base_path + sub_path
          #; [!2ntnk] nested dict mapping can have subclass of Hash as handlers.
          if item.class == mapping_class
            #; [!dj0sh] traverses mapping recursively.
            _traverse_mapping(item, full_path, mapping_class, &block)
          else
            #; [!j0pes] if item is a hash object, converts keys from symbol to string.
            item = _normalize_method_mapping(item) if item.is_a?(Hash)
            #; [!brhcs] yields block for each full path and handler.
            yield full_path, item
          end
        end
      end

      def _normalize_method_mapping(dict)
        return @router.normalize_method_mapping(dict)
      end

      public

      def build_tree(entrypoint_pairs)
        #; [!6oa05] builds nested hash object from mapping data.
        tree = {}         # tree is a nested dict
        pnames_d = {}
        entrypoint_pairs.each do |path, item|
          d = tree
          rexp, pnames = _parse_path(path, pnames_d) do |str, pat1|
            #; [!po6o6] param regexp should be stored into nested dict as a Symbol.
            d = _next_dict(d, str) unless str.empty?
            d = (d[pat1.intern] ||= {}) if pat1      # ex: pat1=='[^./?]+'
          end
          #; [!kz8m7] range object should be included into tuple if only one param exist.
          if @enable_range
            range, separator = _range_of_urlpath_param(path)
          else
            range = separator = nil
          end
          #; [!c6xmp] tuple should be stored into nested dict with key 'nil'.
          d[nil] = [rexp, pnames, item, range, separator]
        end
        return tree
      end

      private

      def _parse_path(path, pnames_d, &b)
        sb = ['\A']
        pos = 0
        pnames = []
        #; [!uyupj] handles urlpath parameter such as ':id'.
        #; [!j9cdy] handles optional urlpath parameter such as '(.:format)'.
        path.scan(/:(\w+)|\((.*?)\)/) do
          param = $1; optional = $2         # ex: $1=='id' or $2=='.:format'
          m = Regexp.last_match()
          str = path[pos, m.begin(0) - pos]
          pos = m.end(0)
          #; [!akkkx] converts urlpath param into regexp.
          #; [!lwgt6] handles '|' (OR) pattern in '()' such as '(.html|.json)'.
          pat1, pat2 = _param_patterns(param, optional) do |pname|
            pname.freeze
            pnames << (pnames_d[pname] ||= pname)
          end
          yield str, pat1
          #; [!zoym3] urlpath string should be escaped.
          sb << Regexp.escape(str) << pat2  # ex: pat2=='([^./?]+)'
        end
        #; [!o642c] remained string after param should be handled correctly.
        str = pos == 0 ? path : path[pos..-1]
        unless str.empty?
          yield str, nil
          sb << Regexp.escape(str)          # ex: str=='.html'
        end
        sb << '\z'
        return Regexp.compile(sb.join()), pnames
      end

      def _next_dict(d, str)
        #; [!s1rzs] if new key exists in dict...
        if d.key?(str)
          #; [!io47b] just returns corresponding value and not change dict.
          return d[str]
        end
        #; [!3ndpz] returns next dict.
        d2 = nil          # next dict
        c = str[0]
        found = false
        d.keys.each do |key|
          if found
            #; [!5fh08] keeps order of keys in dict.
            d[key] = d.delete(key)
          #; [!4wdi7] ignores Symbol key (which represents regexp).
          #; [!66sdb] ignores nil key (which represents leaf node).
          elsif key.is_a?(String) && key[0] == c
            found = true
            prefix, rest1, rest2 = _common_prefix(key, str)
            #; [!46o9b] if existing key is same as common prefix...
            if rest1.empty?
              #; [!4ypls] not replace existing key.
              val = d[key]
              d2 = _next_dict(val, rest2)
              break
            #; [!veq0q] if new key is same as common prefix...
            elsif rest2.empty?
              #; [!0tboh] replaces existing key with ney key.
              val = d.delete(key)
              d2 = {rest1 => val}
              d[prefix] = d2
            #; [!esszs] if common prefix is a part of exsting key and new key...
            else
              #; [!pesq0] replaces existing key with common prefix.
              val = d.delete(key)
              d2 = {}
              d[prefix] = {rest1 => val, rest2 => d2}
            end
          end
        end
        #; [!viovl] if new key has no common prefix with existing keys...
        unless found
          #; [!i6smv] adds empty dict with new key.
          d2 = {}
          d[str] = d2
        end
        return d2
      end

      def _common_prefix(str1, str2)    # ex: "/api/books/" and "/api/blog/"
        #; [!86tsd] calculates common prefix of two strings.
        #n = [str1.length, str2.length].min()
        n1 = str1.length; n2 = str2.length
        n = n1 < n2 ? n1 : n2
        i = 0
        while i < n && str1[i] == str2[i]
          i += 1
        end
        #; [!1z2ii] returns common prefix and rest of strings.
        prefix = str1[0...i]            # ex: "/api/b"
        rest1  = str1[i..-1]            # ex: "ooks/"
        rest2  = str2[i..-1]            # ex: "log/"
        return prefix, rest1, rest2
      end

      def _param_patterns(param, optional, &callback)
        #; [!j90mw] returns '[^./?]+' and '([^./?]+)' if param specified.
        if param
          optional == nil  or raise "** internal error"
          yield param
          pat1 = _param2rexp(param)     # ex: '[^./?]+'
          pat2 = "(#{pat1})"
        #; [!raic7] returns '(?:\.[^./?]+)?' and '(?:\.([^./?]+))?' if optional param is '(.:format)'.
        elsif optional == ".:format"
          yield "format"
          pat1 = '(?:\.[^./?]+)?'
          pat2 = '(?:\.([^./?]+))?'
        #; [!69yj9] optional string can contains other params.
        elsif optional
          sb = ['(?:']
          #; [!oh9c6] optional string can have '|' (OR).
          optional.split('|').each_with_index do |string, i|
            sb << '|' if i > 0
            string.scan(/(.*?)(?::(\w+))/) do |str, param_|
              pat = _param2rexp(param)                  # ex: pat == '[^./?]+'
              sb << Regexp.escape(str) << "<<#{pat}>>"  # ex: sb << '(?:\.<<[^./?]+>>)?'
              yield param_
            end
            sb << Regexp.escape($' || string)
          end
          sb << ')?'
          s = sb.join()
          pat1 = s.gsub('<<', '' ).gsub('>>', '' )    # ex: '(?:\.[^./?]+)?'
          pat2 = s.gsub('<<', '(').gsub('>>', ')')    # ex: '(?:\.([^./?]+))?'
        else
          raise "** internal error"
        end
        return pat1, pat2
      end

      def _param2rexp(param)
        return @router.param2rexp(param)    # ex: '[^./?]+'
      end

      public

      def build_rexp(tree, &callback)
        #; [!65yw6] converts nested dict into regexp.
        sb = ['\A']
        _build_rexp(tree, sb, &callback)
        sb << '\z'
        return Regexp.compile(sb.join())
      end

      private

      def _build_rexp(nested_dict, sb, &b)
        #; [!hs7vl] '(?:)' and '|' are added only if necessary.
        sb << '(?:' if nested_dict.length > 1
        nested_dict.each_with_index do |(k, v), i|
          sb << '|' if i > 0
          #; [!7v7yo] nil key means leaf node and yields block argument.
          #; [!hda6m] string key should be escaped.
          #; [!b9hxc] symbol key means regexp string.
          case k
          when nil    ; sb << '(\z)'           ; yield v
          when String ; sb << Regexp.escape(k) ; _build_rexp(v, sb, &b)
          when Symbol ; sb << k.to_s           ; _build_rexp(v, sb, &b)
          else        ; raise "** internal error"
          end
        end
        sb << ')' if nested_dict.length > 1
      end

      def _range_of_urlpath_param(urlpath_pattern)      # ex: '/books/:id/comments/:comment_id.json'
        #; [!93itq] returns nil if urlpath pattern includes optional parameters.
        return nil if urlpath_pattern =~ /\(/
        #; [!syrdh] returns Range object when urlpath_pattern contains just one param.
        #; [!elsdx] returns Range and separator string when urlpath_pattern contains two params.
        #; [!skh4z] returns nil when urlpath_pattern contains more than two params.
        #; [!acj5b] returns nil when urlpath_pattern contains no params.
        rexp = /:\w+/
        arr = urlpath_pattern.split(rexp, -1)   # ex: ['/books/', '/comments/', '.json']
        case arr.length
        when 2                                  # ex: arr == ['/books/', '.json']
          range = arr[0].length .. -(arr[1].length+1)
          return range, nil                     # ex: (7..-6), nil
        when 3                                  # ex: arr == ['/books/', '/comments/', '.json']
          return nil if arr[1].empty?
          range = arr[0].length .. -(arr[2].length+1)
          return range, arr[1]                  # ex: (7..-6), '/comments/'
        else
          return nil
        end
      end

    end


  end


end
