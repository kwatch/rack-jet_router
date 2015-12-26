# -*- coding: utf-8 -*-

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
  ##   router.find('/api/books/123.html')
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
  ##   router.find('/api/books/123')
  ##       #=> [{"GET"=>book_show_api, "PUT"=>book_update_api}, {"id"=>"123", "format"=>nil}]
  ##   status, headers, body = router.call(env)
  ##
  class JetRouter

    def initialize(mapping, urlpath_cache_size: 0)
      #; [!u2ff4] compiles urlpath mapping.
      (@urlpath_rexp,          # ex: {'/api/books'=>BooksApp}
       @fixed_urlpath_dict,    # ex: [[%r'\A/api/books/([^./]+)\z', ['id'], BookApp]]
       @variable_urlpath_list, # ex: %r'\A(?:/api(?:/books(?:/[^./]+(\z))))\z'
      ) = compile_mapping(mapping)
      ## cache for variable urlpath (= containg urlpath parameters)
      @urlpath_cache_size = urlpath_cache_size
      @variable_urlpath_cache = urlpath_cache_size > 0 ? {} : nil
    end

    ## Finds rack app according to PATH_INFO and REQUEST_METHOD and invokes it.
    def call(env)
      #; [!fpw8x] finds mapped app according to env['PATH_INFO'].
      req_path = env['PATH_INFO']
      app, urlpath_params = find(req_path)
      #; [!wxt2g] guesses correct urlpath and redirects to it automaticaly when request path not found.
      #; [!3vsua] doesn't redict automatically when request path is '/'.
      unless app || req_path == '/'
        location = req_path =~ /\/\z/ ? req_path[0..-2] : req_path + '/'
        app, urlpath_params = find(location)
        return redirect_to(location) if app
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
    ##    find('/api/books/123')   #=> [BookApp, {"id"=>"123"}]
    def find(req_path)
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
      rexp_buf          = ['\A']
      fixed_urlpaths    = {}  # ex: {'/api/books'=>BooksApp}
      variable_urlpaths = []  # ex: [[%r'\A/api/books/([^./]+)\z', ['id'], BookApp]]
      _compile_array(mapping, rexp_buf, '', '',
                      fixed_urlpaths, variable_urlpaths)
      ## ex: %r'\A(?:/api(?:/books(?:/[^./]+(\z)|/[^./]+/edit(\z))))\z'
      rexp_buf << '\z'
      urlpath_rexp = Regexp.new(rexp_buf.join())
      #; [!xzo7k] returns regexp, hash, and array.
      return urlpath_rexp, fixed_urlpaths, variable_urlpaths
    end

    def _compile_array(mapping, rexp_buf, base_urlpath_pat, urlpath_pat,
                       fixed_dict, variable_list)
      rexp_str, _ = compile_urlpath_pattern(urlpath_pat, false)
      rexp_buf << rexp_str
      rexp_buf << '(?:'
      len = rexp_buf.length
      mapping.each do |child_urlpath_pat, obj|
        rexp_buf << '|' if rexp_buf.length != len
        curr_urlpath_pat = "#{base_urlpath_pat}#{urlpath_pat}"
        #; [!ospaf] accepts nested mapping.
        if obj.is_a?(Array)
          _compile_array(obj, rexp_buf, curr_urlpath_pat, child_urlpath_pat,
                         fixed_dict, variable_list)
        #; [!2ktpf] handles end-point.
        else
          _compile_object(obj, rexp_buf, curr_urlpath_pat, child_urlpath_pat,
                          fixed_dict, variable_list)
        end
      end
      #; [!gfxgr] deletes unnecessary grouping.
      if rexp_buf.length == len
        x = rexp_buf.pop()    # delete '(?:'
        x == '(?:'  or raise "assertion failed"
        #; [!pv2au] deletes unnecessary urlpath regexp.
        x = rexp_buf.pop()    # delete rexp_str
        x == rexp_str  or raise "assertion failed"
      #; [!bh9lo] deletes unnecessary grouping which contains only an element.
      elsif rexp_buf.length == len + 1
        rexp_buf[-2] == '(?:'  or raise "assertion failed: rexp_buf[-2]=#{rexp_buf[-2].inspect}"
        rexp_buf[-2] = ''
      else
        rexp_buf << ')'
      end
    end

    def _compile_object(obj, rexp_buf, base_urlpath_pat, urlpath_pat,
                        fixed_dict, variable_list)
      #; [!guhdc] if mapping dict is specified...
      if obj.is_a?(Hash)
        obj = normalize_mapping_keys(obj)
      end
      #; [!l63vu] handles urlpath pattern as fixed when no urlpath params.
      full_urlpath_pat = "#{base_urlpath_pat}#{urlpath_pat}"
      full_urlpath_rexp_str, param_names = compile_urlpath_pattern(full_urlpath_pat, true)
      fixed_pattern = param_names.nil?
      if fixed_pattern
        fixed_dict[full_urlpath_pat] = obj
      #; [!vfytw] handles urlpath pattern as variable when urlpath param exists.
      else
        rexp_str, _ = compile_urlpath_pattern(urlpath_pat, false)
        rexp_buf << (rexp_str << '(\z)')
        full_urlpath_rexp = Regexp.new("\\A#{full_urlpath_rexp_str}\\z")
        range = range_of_urlpath_param(full_urlpath_pat)
        variable_list << [full_urlpath_rexp, param_names, obj, range]
      end
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
