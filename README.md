# Rack::JetRouter

Rack::JetRouter is crazy-fast router library for Rack application,
derived from [Keight.rb](https://github.com/kwatch/keight/tree/ruby).


## Benchmark

Benchmark script is [here](https://github.com/kwatch/rack-jet_router/blob/dev/bench/bench.rb).

```
## Ranking                        usec/req
(Rack plain)  /api/hello             1.555 (100.0%) ********************
(JetRouter)   /api/hello             1.597 ( 97.4%) *******************
(JetRouter)   /api/hello/123         6.424 ( 24.2%) *****
(R::Req+Res)  /api/hello             9.837 ( 15.8%) ***
(Sinatra)     /api/hello           106.965 (  1.5%)
(Sinatra)     /api/hello/123       116.672 (  1.3%)
```

* If URL path has no path parameter (such as `/api/hello`),
  Rack::JetRouter is just a litte slower than plain Rack application.
* If URL path contains path parameter (such as `/api/hello/:id`),
  Rack::JetRouter becomes slower, but it is enough small (about 6.4ns/req).
* Overhead of Rack::JetRouter is smaller than that of Rack::Reqeust +
  Rack::Response.
* Sinatra is too slow.


## Examples

### #1: Depends only on Request Path

```ruby
# -*- coding: utf-8 -*-

require 'rack'
require 'rack/jet_router'

## Assume that welcome_app, books_api, ... are Rack application.
urlpath_mapping = [
    ['/'                       , welcome_app],
    ['/api', [
        ['/books', [
            [''                , books_api],
            ['/:id(.:format)'  , book_api],
            ['/:book_id/comments/:comment_id', comment_api],
        ]],
    ]],
    ['/admin', [
        ['/books'              , admin_books_app],
    ]],
]

router = Rack::JetRouter.new(urlpath_mapping)
p router.lookup('/api/books/123.html')
    #=> [book_api, {"id"=>"123", "format"=>"html"}]

status, headers, body = router.call(env)
```


### #2: Depends on both Request Path and Method

```ruby
# -*- coding: utf-8 -*-

require 'rack'
require 'rack/jet_router'

## Assume that welcome_app, book_list_api, ... are Rack application.
urlpath_mapping = [
    ['/'                       , {GET: welcome_app}],
    ['/api', [
        ['/books', [
            [''                , {GET: book_list_api, POST: book_create_api}],
            ['/:id(.:format)'  , {GET: book_show_api, PUT: book_update_api}],
            ['/:book_id/comments/:comment_id', {POST: comment_create_api}],
        ]],
    ]],
    ['/admin', [
        ['/books'              , {ANY: admin_books_app}],
    ]],
]

router = Rack::JetRouter.new(urlpath_mapping)
p router.lookup('/api/books/123')
    #=> [{"GET"=>book_show_api, "PUT"=>book_update_api}, {"id"=>"123", "format"=>nil}]

status, headers, body = router.call(env)
```

Notice that `{GET: ..., PUT: ...}` is converted into `{"GET"=>..., "PUT"=>...}`
automatically when passing to `Rack::JetRouter.new()`.


### #3: RESTful Framework

```ruby
# -*- coding: utf-8 -*-

require 'rack'
require 'rack/jet_router'

class API
  def initialize(request, response)
    @request  = request
    @response = response
  end
  attr_reader :request, :response
end

class BooksAPI < API
  def index(); ....; end
  def create(); ....; end
  def show(id); ....; end
  def update(id: nil); ....; end
  def delete(id: nil); ....; end
end

urlpath_mapping = [
    ['/api', [
        ['/books', [
            [''      , {GET:    [BooksAPI, :index],
                        POST:   [BooksAPI, :create]}],
            ['/:id'  , {GET:    [BooksAPI, :show],
                        PUT:    [BooksAPI, :update],
                        DELETE: [BooksAPI, :delete]}],
        ]],
    ]],
]
router = Rack::JetRouter.new(urlpath_mapping)
p router.lookup('/api/books/123')
    #=> [{"GET"=>[BooksAPI, :show], "PUT"=>..., "DELETE"=>...}, {"id"=>"123"}]

dict, args = router.lookup('/api/books/123')
klass, action = dict["GET"]
handler = klass.new(Rack::Request.new(env), Rack::Response.new)
handler.__send__(action, args)
```


## Topics


### URL Path Parameters

URL path parameters (such as `{"id"=>"123"}`) is available via
`env['rack.urlpath_params']`.

```ruby
BookApp = proc {|env|
  p env['rack.urlpath_params']   #=> {"id"=>"123"}
  [200, {}, []]
}
```

If you want to tweak URL path parameters, define subclass of Rack::JetRouter
and override `#build_urlpath_parameter_vars(env, vars)`.

```ruby
class MyRouter < JetRouter

  def build_urlpath_parameter_vars(names, values)
    return names.zip(values).each_with_object({}) {|(k, v), d|
      ## converts urlpath pavam value into integer
      v = v.to_i if k == 'id' || k.end_with?('_id')
      d[k] = v
    }
  end

end
```


### Variable URL Path Cache

It is possible to classify URL path patterns into two types: fixed and variable.

* **Fixed URL path pattern** doesn't contain any urlpath paramters.<br>
  Example: `/`, `/login`, `/api/books`
* **Variable URL path pattern** contains urlpath parameters.<br>
  Example: `/api/books/:id`, `/index(.:format)`

`Rack::JetRouter` caches only fixed URL path patterns in default.
It is possible for `Rack::JetRouter` to cache variable URL path patterns
as well as fixed ones. It will make routing much faster.

```ruby
## Enable variable urlpath cache.
router = Rack::JetRouter.new(urlpath_mapping, urlpath_cache_size: 200)
p router.lookup('/api/books/123')   # caches even varaible urlpath
```


### Custom Error Response

```ruby
class MyRouter < Rack::JetRouter

  def error_not_found(env)
    html = ("<h2>404 Not Found</h2>\n" \
            "<p>Path: #{env['PATH_INFO']}</p>\n")
    [404, {"Content-Type"=>"text/html"}, [html]]
  end

  def error_not_allowed(env)
    html = ("<h2>405 Method Not Allowed</h2>\n" \
            "<p>Method: #{env['REQUEST_METHOD']}</p>\n")
    [405, {"Content-Type"=>"text/html"}, [html]]
  end

end
```

Above methods are invoked from `Rack::JetRouter#call()`.


## Copyright and License

$Copyright: copyright(c) 2015 kuwata-lab.com all rights reserved $

$License: MIT License $


## History


### 2015-12-06: Release 1.0.1

* Fix document


### 2015-12-06: Release 1.0.0

* First release
