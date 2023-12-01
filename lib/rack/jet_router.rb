# -*- coding: utf-8 -*-
# frozen_string_literal: true

###
### $Release: 0.0.0 $
### $Copyright: copyright(c) 2015 kuwata-lab.com all rights reserved $
### $License: MIT License $
###

require 'rack'


module Rack


  ##
  ## Jet-speed router class, derived from Keight.rb.
  ##
  ## ex:
  ##   urlpath_mapping = [
  ##       ['/'                       , welcome_app],
  ##       ['/api', [
  ##           ['/books', [
  ##               [''                , books_api],
  ##               ['/:id(.:format)'  , book_api],
  ##               ['/:book_id/comments/:comment_id', comment_api],
  ##           ]],
  ##       ]],
  ##       ['/admin', [
  ##           ['/books'              , admin_books_app],
  ##       ]],
  ##   ]
  ##   router = Rack::JetRouter.new(urlpath_mapping)
  ##   router.lookup('/api/books/123.html')
  ##       #=> [book_api, {"id"=>"123", "format"=>"html"}]
  ##   status, headers, body = router.call(env)
  ##
  ##   ### or:
  ##   urlpath_mapping = [
  ##       ['/'                       , {GET: welcome_app}],
  ##       ['/api', [
  ##           ['/books', [
  ##               [''                , {GET: book_list_api, POST: book_create_api}],
  ##               ['/:id(.:format)'  , {GET: book_show_api, PUT: book_update_api}],
  ##               ['/:book_id/comments/:comment_id', {POST: comment_create_api}],
  ##           ]],
  ##       ]],
  ##       ['/admin', [
  ##           ['/books'              , {ANY: admin_books_app}],
  ##       ]],
  ##   ]
  ##   router = Rack::JetRouter.new(urlpath_mapping)
  ##   router.lookup('/api/books/123')
  ##       #=> [{"GET"=>book_show_api, "PUT"=>book_update_api}, {"id"=>"123", "format"=>nil}]
  ##   status, headers, body = router.call(env)
  ##
  class JetRouter

    RELEASE = '$Release: 0.0.0 $'.split()[1]

    def initialize(mapping, urlpath_cache_size: 0,
                            enable_urlpath_param_range: true)
      @enable_urlpath_param_range = enable_urlpath_param_range
      #; [!u2ff4] compiles urlpath mapping.
      (@urlpath_rexp,          # ex: {'/api/books'=>BooksApp}
       @fixed_urlpath_dict,    # ex: [[%r'\A/api/books/([^./]+)\z', ['id'], BookApp]]
       @variable_urlpath_list, # ex: %r'\A(?:/api(?:/books(?:/[^./]+(\z))))\z'
       @all_entrypoints,       # ex: [['/api/books', BooksAPI'], ['/api/orders', OrdersAPI]]
      ) = compile_mapping(mapping)
      ## cache for variable urlpath (= containg urlpath parameters)
      @urlpath_cache_size = urlpath_cache_size
      @variable_urlpath_cache = urlpath_cache_size > 0 ? {} : nil
    end

    attr_reader :urlpath_rexp

    ## Finds rack app according to PATH_INFO and REQUEST_METHOD and invokes it.
    def call(env)
      #; [!fpw8x] finds mapped app according to env['PATH_INFO'].
      req_path = env['PATH_INFO']
      app, urlpath_params = lookup(req_path)
      #; [!wxt2g] guesses correct urlpath and redirects to it automaticaly when request path not found.
      #; [!3vsua] doesn't redict automatically when request path is '/'.
      if ! app && should_redirect?(env)
        location = req_path =~ /\/\z/ ? req_path[0..-2] : req_path + '/'
        app, urlpath_params = lookup(location)
        if app
          #; [!hyk62] adds QUERY_STRING to redirect location.
          qs = env['QUERY_STRING']
          location = "#{location}?#{qs}" if qs && ! qs.empty?
          return redirect_to(location)
        end
      end
      #; [!30x0k] returns 404 when request urlpath not found.
      return error_not_found(env) unless app
      #; [!gclbs] if mapped object is a Hash...
      if app.is_a?(Hash)
        #; [!p1fzn] invokes app mapped to request method.
        #; [!5m64a] returns 405 when request method is not allowed.
        #; [!ys1e2] uses GET method when HEAD is not mapped.
        #; [!2hx6j] try ANY method when request method is not mapped.
        dict = app
        req_meth = env['REQUEST_METHOD']
        app = dict[req_meth] || (req_meth == 'HEAD' ? dict['GET'] : nil) || dict['ANY']
        return error_not_allowed(env) unless app
      end
      #; [!2c32f] stores urlpath parameters as env['rack.urlpath_params'].
      store_urlpath_params(env, urlpath_params)
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
      obj = @fixed_urlpath_dict[req_path]
      return obj, nil if obj
      #; [!upacd] finds in variable urlpath cache if it is enabled.
      #; [!1zx7t] variable urlpath cache is based on LRU.
      cache = @variable_urlpath_cache
      if cache && (pair = cache.delete(req_path))
        cache[req_path] = pair
        return pair
      end
      #; [!vpdzn] returns nil when urlpath not found.
      m = @urlpath_rexp.match(req_path)
      return nil unless m
      index = m.captures.find_index('')
      return nil unless index
      #; [!ijqws] returns mapped object and urlpath parameter values when urlpath found.
      full_urlpath_rexp, param_names, obj, range = @variable_urlpath_list[index]
      if range
        ## "/books/123"[7..-1] is faster than /\A\/books\/(\d+)\z/.match("/books/123")
        str = req_path[range]
        param_values = [str]
      else
        m = full_urlpath_rexp.match(req_path)
        param_values = m.captures
      end
      vars = build_urlpath_parameter_vars(param_names, param_values)
      #; [!84inr] caches result when variable urlpath cache enabled.
      if cache
        cache.shift() if cache.length >= @urlpath_cache_size
        cache[req_path] = [obj, vars]
      end
      return obj, vars
    end

    alias find lookup      # :nodoc:      # for backward compatilibity

    ## Yields pair of urlpath pattern and app.
    def each(&block)
      #; [!ep0pw] yields pair of urlpath pattern and app.
      @all_entrypoints.each(&block)
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
      content = "Redirect to #{location}"
      return [301, {"Content-Type"=>"text/plain", "Location"=>location}, [content]]
    end

    ## Sets env['rack.urlpath_params'] = vars. Override in subclass if necessary.
    def store_urlpath_params(env, vars)
      env['rack.urlpath_params'] = vars if vars
    end

    ## Returns Hash object representing urlpath parameters. Override if necessary.
    ##
    ## ex:
    ##     class MyRouter < JetRouter
    ##       def build_urlpath_parameter_vars(names, values)
    ##         return names.zip(values).each_with_object({}) {|(k, v), d|
    ##           ## converts urlpath pavam value into integer
    ##           v = v.to_i if k == 'id' || k.end_with?('_id')
    ##           d[k] = v
    ##         }
    ##       end
    ##     end
    def build_urlpath_parameter_vars(names, values)
      return Hash[names.zip(values)]
    end

    private

    ## Compiles urlpath mapping. Called from '#initialize()'.
    def compile_mapping(mapping)
      ## entry points which has no urlpath parameters
      ## ex:
      ##   { '/'           => HomeApp,
      ##     '/api/books'  => BooksApp,
      ##     '/api/authors => AuthorsApp,
      ##   }
      dict = {}
      ## entry points which has one or more urlpath parameters
      ## ex:
      ##   [
      ##     [%r!\A/api/books/([^./]+)\z!,   ["id"], BookApp,   (11..-1)],
      ##     [%r!\A/api/authors/([^./]+)\z!, ["id"], AuthorApp, (12..-1)],
      ##   ]
      list = []
      #
      all = []
      rexp_str = _compile_mapping(mapping, "", "") do |entry_point|
        obj, urlpath_pat, urlpath_rexp, param_names = entry_point
        all << [urlpath_pat, obj]
        if urlpath_rexp
          range = @enable_urlpath_param_range ? range_of_urlpath_param(urlpath_pat) : nil
          list << [urlpath_rexp, param_names, obj, range]
        else
          dict[urlpath_pat] = obj
        end
      end
      ## ex: %r!^A(?:api(?:/books/[^./]+(\z)|/authors/[^./]+(\z)))\z!
      urlpath_rexp = Regexp.new("\\A#{rexp_str}\\z")
      #; [!xzo7k] returns regexp, hash, and array.
      return urlpath_rexp, dict, list, all
    end

    def _compile_mapping(mapping, base_urlpath, parent_urlpath, &block)
      arr = []
      mapping.each do |urlpath, obj|
        full_urlpath = "#{base_urlpath}#{urlpath}"
        #; [!ospaf] accepts nested mapping.
        if obj.is_a?(Array)
          rexp_str = _compile_mapping(obj, full_urlpath, urlpath, &block)
        #; [!2ktpf] handles end-point.
        else
          #; [!guhdc] if mapping dict is specified...
          if obj.is_a?(Hash)
            obj = normalize_mapping_keys(obj)
          end
          #; [!vfytw] handles urlpath pattern as variable when urlpath param exists.
          full_urlpath_rexp_str, param_names = compile_urlpath_pattern(full_urlpath, true)
          if param_names   # has urlpath params
            full_urlpath_rexp = Regexp.new("\\A#{full_urlpath_rexp_str}\\z")
            rexp_str, _ = compile_urlpath_pattern(urlpath, false)
            rexp_str << '(\z)'
            entry_point = [obj, full_urlpath, full_urlpath_rexp, param_names]
          #; [!l63vu] handles urlpath pattern as fixed when no urlpath params.
          else             # has no urlpath params
            entry_point = [obj, full_urlpath, nil, nil]
          end
          yield entry_point
        end
        arr << rexp_str if rexp_str
      end
      #; [!pv2au] deletes unnecessary urlpath regexp.
      return nil if arr.empty?
      #; [!bh9lo] deletes unnecessary grouping.
      parent_urlpath_rexp_str, _ = compile_urlpath_pattern(parent_urlpath, false)
      return "#{parent_urlpath_rexp_str}#{arr[0]}" if arr.length == 1
      #; [!iza1g] adds grouping if necessary.
      return "#{parent_urlpath_rexp_str}(?:#{arr.join('|')})"
    end

    ## Compiles '/books/:id' into ['/books/([^./]+)', ["id"]].
    def compile_urlpath_pattern(urlpath_pat, enable_capture=true)
      s = "".dup()
      param_pat = enable_capture ? '([^./]+)' : '[^./]+'
      param_names = []
      pos = 0
      urlpath_pat.scan(/:(\w+)|\((.*?)\)/) do |name, optional|
        #; [!joozm] escapes metachars with backslash in text part.
        m = Regexp.last_match
        text = urlpath_pat[pos...m.begin(0)]
        pos = m.end(0)
        s << Regexp.escape(text)
        #; [!rpezs] converts '/books/:id' into '/books/([^./]+)'.
        if name
          param_names << name
          s << param_pat
        #; [!4dcsa] converts '/index(.:format)' into '/index(?:\.([^./]+))?'.
        elsif optional
          s << '(?:'
          optional.scan(/(.*?)(?::(\w+))/) do |text2, name2|
            s << Regexp.escape(text2) << param_pat
            param_names << name2
          end
          s << Regexp.escape($' || optional)
          s << ')?'
        #
        else
          raise "unreachable: urlpath=#{urlpath.inspect}"
        end
      end
      #; [!1d5ya] rethrns compiled string and nil when no urlpath parameters nor parens.
      #; [!of1zq] returns compiled string and urlpath param names when urlpath param or parens exist.
      if pos == 0
        return Regexp.escape(urlpath_pat), nil
      else
        s << Regexp.escape(urlpath_pat[pos..-1])
        return s, param_names
      end
    end

    def range_of_urlpath_param(urlpath_pattern)      # ex: '/books/:id/edit'
      #; [!syrdh] returns Range object when urlpath_pattern contains just one param.
      #; [!skh4z] returns nil when urlpath_pattern contains more than two params.
      #; [!acj5b] returns nil when urlpath_pattern contains no params.
      rexp = /:\w+|\(.*?\)/
      arr = urlpath_pattern.split(rexp, -1)          # ex: ['/books/', '/edit']
      return nil unless arr.length == 2
      return (arr[0].length .. -(arr[1].length+1))   # ex: 7..-6  (Range object)
    end

    def normalize_mapping_keys(dict)
      #; [!r7cmk] converts keys into string.
      #; [!z9kww] allows 'ANY' as request method.
      #; [!k7sme] raises error when unknown request method specified.
      request_methods = REQUEST_METHODS
      return dict.each_with_object({}) do |(meth, app), newdict|
        meth_str = meth.to_s
        request_methods[meth_str] || meth_str == 'ANY'  or
          raise ArgumentError.new("#{meth.inspect}: unknown request method.")
        newdict[meth_str] = app
      end
    end

    #; [!haggu] contains available request methods.
    REQUEST_METHODS = %w[GET POST PUT DELETE PATCH HEAD OPTIONS TRACE LINK UNLINK] \
                        .each_with_object({}) {|s, d| d[s] = s.intern }

  end


end
